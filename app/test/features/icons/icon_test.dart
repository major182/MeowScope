import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meowscope/core/api/api_error.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/icons/icon_avatar.dart';
import 'package:meowscope/features/icons/icon_crop_screen.dart';
import 'package:meowscope/features/icons/icon_repository.dart';
import 'package:meowscope/features/photos/data/photo_picker.dart';
import 'package:meowscope/features/photos/data/photo_repository.dart';
import 'package:meowscope/features/sync/data/sync_engine.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

Uint8List jpeg(int w, int h) => img.encodeJpg(img.Image(width: w, height: h));

class FakePicker implements PhotoPicker {
  FakePicker(this.result);
  final Uint8List? result;

  @override
  Future<Uint8List?> pick(PhotoSource source) async => result;
}

/// 画面のテスト用。ファイルを書かず、呼ばれたことだけを覚える
class FakeIconRepository extends IconRepository {
  FakeIconRepository(AppDatabase db, Dio dio)
    : super(db, dio, () async => Directory.systemTemp);

  Object? error;
  final calls = <(IconOwner, String)>[];

  /// 渡された画像（切り抜いた結果を確かめる）
  final bytes = <Uint8List>[];

  @override
  Future<void> setIcon(IconOwner owner, String id, Uint8List bytes) async {
    if (error != null) {
      throw error!;
    }
    calls.add((owner, id));
    this.bytes.add(bytes);
  }
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeServer server;
  late MemoryTokenStore tokens;
  late IconRepository repo;

  setUp(() async {
    db = memoryDatabase();
    dir = Directory.systemTemp.createTempSync('meowscope_icons_');
    server = FakeServer();
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    repo = IconRepository(db, fakeApiClient(server, tokens), () async => dir);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('UT-IC-01 設定：512px に縮めて送り、端末に保存し、アイコンありにする（猫は /cats、自分は /me）', () async {
    server.on('PUT', '/cats/c1/icon', (r) => const FakeResponse(204));
    server.on('PUT', '/me/icon', (r) => const FakeResponse(204));

    await repo.setIcon(IconOwner.cat, 'c1', jpeg(2000, 1000));
    await repo.setIcon(IconOwner.user, 'u1', jpeg(100, 100));

    final sent = server.sentTo('/cats/c1/icon').single;
    expect(sent.contentType, 'image/jpeg');
    expect(
      img.decodeImage(Uint8List.fromList(sent.data as List<int>))!.width,
      512,
    );
    expect(server.sentTo('/me/icon'), hasLength(1));
    expect((await db.select(db.cats).getSingle()).hasIcon, isTrue);
    // 端末で設定したものは、通信なしで出せる
    final before = server.requests.length;
    expect(await repo.load(const IconRef(IconOwner.cat, 'c1')), isNotNull);
    expect(server.requests.length, before);
  });

  test('UT-IC-02 異常系：読めない画像は送らない。送れなければ保存しない', () async {
    await expectLater(
      repo.setIcon(IconOwner.cat, 'c1', Uint8List.fromList([1, 2])),
      throwsA(isA<PhotoUnreadable>()),
    );
    expect(server.requests, isEmpty);

    server.on('PUT', '/cats/c1/icon', (r) => const FakeResponse(413));
    await expectLater(
      repo.setIcon(IconOwner.cat, 'c1', jpeg(10, 10)),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 413)),
    );
    expect((await db.select(db.cats).getSingle()).hasIcon, isFalse);
    expect(await repo.load(const IconRef(IconOwner.cat, 'c1')), isNull);
  });

  test('UT-IC-03 表示：サーバーから取って保存し、同じ版なら取り直さず、版が変われば取り直す。オフラインなら前の画像', () async {
    var calls = 0;
    server.on('GET', '/users/u2/icon', (r) {
      calls++;
      return FakeResponse(200, Uint8List.fromList([0xFF, 0xD8, calls]));
    });

    final v1 = await repo.load(
      const IconRef(IconOwner.user, 'u2', hasIcon: true, version: 1),
    );
    final again = await repo.load(
      const IconRef(IconOwner.user, 'u2', hasIcon: true, version: 1),
    );
    final v2 = await repo.load(
      const IconRef(IconOwner.user, 'u2', hasIcon: true, version: 2),
    );
    expect((v1, again, v2).$1, [0xFF, 0xD8, 1]);
    expect(again, [0xFF, 0xD8, 1]);
    expect(v2, [0xFF, 0xD8, 2]);
    expect(calls, 2);

    server.on('GET', '/users/u2/icon', (r) => const FakeResponse.offline());
    expect(
      await repo.load(
        const IconRef(IconOwner.user, 'u2', hasIcon: true, version: 3),
      ),
      [0xFF, 0xD8, 2],
    );
    expect(
      await repo.load(
        const IconRef(IconOwner.user, 'u3', hasIcon: true, version: 1),
      ),
      isNull,
    );
    expect(await repo.load(const IconRef(IconOwner.user, 'u4')), isNull);
  });

  test('UT-IC-04 同期で猫とユーザーのアイコンの有無と版を受け取る', () async {
    await db
        .into(db.householdMembers)
        .insert(
          HouseholdMembersCompanion.insert(
            id: 'm1',
            createdAt: testTime,
            updatedAt: testTime,
            householdId: 'h1',
            userId: const Value('u2'),
          ),
        );
    server.on(
      'POST',
      '/sync',
      (r) => const FakeResponse(200, {
        'results': [],
        'changes': [
          {
            'table': 'cats',
            'id': 'c1',
            'seq': 5,
            'updatedAt': '2026-11-03T00:00:00Z',
            'deletedAt': null,
            'data': {
              'householdId': 'h1',
              'name': 'ミケ',
              'status': 'active',
              'hasIcon': true,
            },
          },
          {
            'table': 'users',
            'id': 'u2',
            'seq': 6,
            'updatedAt': '2026-11-03T00:00:00Z',
            'deletedAt': null,
            'data': {'displayName': 'なつ', 'hasIcon': true},
          },
        ],
        'nextSeq': 6,
        'hasMore': false,
        'fullResyncRequired': false,
      }),
    );

    await SyncEngine(db, fakeApiClient(server, tokens), tokens).run('u1');

    final cat = await db.select(db.cats).getSingle();
    expect((cat.hasIcon, cat.serverSeq), (true, 5));
    final member = await db.select(db.householdMembers).getSingle();
    expect((member.hasIcon, member.iconSeq), (true, 6));
  });

  group('画面', () {
    late FakeIconRepository fake;

    Future<void> show(
      WidgetTester tester,
      Widget child, {
      Uint8List? image,
      Uint8List? picked,
    }) async {
      fake = FakeIconRepository(db, fakeApiClient(server, tokens));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconRepositoryProvider.overrideWithValue(fake),
            photoPickerProvider.overrideWithValue(FakePicker(picked)),
            iconImageProvider.overrideWith((ref, icon) async => image),
          ],
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('UT-IC-05 アイコンがなければ既定のイラスト（猫・ユーザー）を出す', (tester) async {
      await show(
        tester,
        const Column(
          children: [
            IconAvatar(icon: IconRef(IconOwner.cat, 'c1')),
            IconAvatar(icon: IconRef(IconOwner.user, 'u1')),
          ],
        ),
      );
      final images = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .map((a) => (a.backgroundImage! as AssetImage).assetName);
      expect(images, [
        'assets/icons/default_cat.png',
        'assets/icons/default_user.png',
      ]);
    });

    testWidgets('UT-IC-06 押すと選んだ画像の範囲を決めてアイコンにする。選ばなければ何もしない', (tester) async {
      await show(
        tester,
        const EditableIcon(icon: IconRef(IconOwner.cat, 'c1')),
        picked: jpeg(20, 10),
      );
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      // 切り抜きの画面（F-SH-10）で「決定」すると、正方形に切り抜いた画像を渡す
      expect(find.byType(IconCropScreen), findsOneWidget);
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      expect(fake.calls, [(IconOwner.cat, 'c1')]);
      final sent = img.decodeImage(fake.bytes.single)!;
      expect((sent.width, sent.height), (10, 10));
      expect(find.text('アイコンを変更しました'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await show(
        tester,
        const EditableIcon(icon: IconRef(IconOwner.cat, 'c1')),
      );
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
    });

    testWidgets('UT-IC-07 異常系：送れなければ理由を出し、読めない画像はその旨を出す', (tester) async {
      await show(
        tester,
        const EditableIcon(icon: IconRef(IconOwner.user, 'u1')),
        picked: jpeg(10, 10),
      );
      fake.error = const ApiError();
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      expect(find.text('サーバーにつながりません。通信の状態を確かめてください'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      fake.error = const PhotoUnreadable();
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      expect(find.text('この画像は読み込めませんでした'), findsOneWidget);
    });

    testWidgets('UT-IC-08 切り抜きの画面を閉じたら何もしない。読めない画像は切り抜きの画面を出さない', (
      tester,
    ) async {
      await show(
        tester,
        const EditableIcon(icon: IconRef(IconOwner.cat, 'c1')),
        picked: jpeg(20, 10),
      );
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(find.text('アイコンを変更しました'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await show(
        tester,
        const EditableIcon(icon: IconRef(IconOwner.cat, 'c1')),
        picked: Uint8List.fromList([1, 2]),
      );
      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      expect(find.byType(IconCropScreen), findsNothing);
      expect(find.text('この画像は読み込めませんでした'), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('UT-IC-09 変えたら、同じ猫の別の版の表示も読み直す（不具合 #248）', (tester) async {
      fake = FakeIconRepository(db, fakeApiClient(server, tokens));
      // 版ごとに読んだ回数を数える
      final loads = <int?, int>{};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconRepositoryProvider.overrideWithValue(fake),
            photoPickerProvider.overrideWithValue(FakePicker(jpeg(20, 10))),
            iconImageProvider.overrideWith((ref, icon) async {
              loads[icon.version] = (loads[icon.version] ?? 0) + 1;
              return null;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // プロフィールは開いたときの版（1）、下の一覧は同期の後の版（2）を出している
                  EditableIcon(
                    icon: IconRef(
                      IconOwner.cat,
                      'c1',
                      hasIcon: true,
                      version: 1,
                    ),
                  ),
                  IconAvatar(
                    icon: IconRef(
                      IconOwner.cat,
                      'c1',
                      hasIcon: true,
                      version: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, {1: 1, 2: 1});

      await tester.tap(find.text('アイコンを変える'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      expect(fake.calls, [(IconOwner.cat, 'c1')]);
      // 版 2 の表示も読み直される
      expect(loads, {1: 2, 2: 2});
    });
  });
}
