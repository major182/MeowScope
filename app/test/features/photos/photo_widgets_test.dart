import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/photos/data/photo_picker.dart';
import 'package:meowscope/features/photos/data/photo_repository.dart';
import 'package:meowscope/features/photos/presentation/photo_widgets.dart';

import '../../helpers/test_db.dart';
import 'photo_test.dart' show addRecordRow;

/// 選んだ写真の元を覚え、決めた画像を返す
class FakePicker implements PhotoPicker {
  FakePicker(this.result);

  final Uint8List? result;
  final sources = <PhotoSource>[];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    sources.add(source);
    return result;
  }
}

/// ファイルに書かずに、写真の情報だけを入れる（画面のテストでは本物のファイルの読み書きが進まないため）
class FakePhotoRepository extends PhotoRepository {
  FakePhotoRepository(this.db) : super(db, () async => Directory.systemTemp);

  final AppDatabase db;
  var unreadable = false;

  @override
  Future<String> addPhoto({
    required String recordId,
    required String userId,
    required Uint8List bytes,
  }) async {
    if (unreadable) {
      throw const PhotoUnreadable();
    }
    // 画面のテストの中では drift の見張り（watch の first）が進まないので、直接読む
    final count =
        (await (db.select(db.recordPhotos)..where(
                  (p) => p.recordId.equals(recordId) & p.deletedAt.isNull(),
                ))
                .get())
            .length;
    if (count >= maxPhotosPerRecord) {
      throw const PhotoLimitReached();
    }
    final id = 'p${count + 1}';
    await insertPhoto(db, id, count + 1);
    return id;
  }
}

Future<void> insertPhoto(AppDatabase db, String id, int sort) => db
    .into(db.recordPhotos)
    .insert(
      RecordPhotosCompanion.insert(
        id: id,
        createdAt: testTime,
        updatedAt: testTime,
        recordId: 'r1',
        sortOrder: sort,
        uploaded: const Value(true),
      ),
    );

void main() {
  late AppDatabase db;
  late FakePicker picker;
  late FakePhotoRepository repo;

  setUp(() async {
    db = memoryDatabase();
    picker = FakePicker(Uint8List.fromList([1]));
    repo = FakePhotoRepository(db);
    await addRecordRow(db, 'r1');
  });
  tearDown(() => db.close());

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    PhotoImage? image,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoRepositoryProvider.overrideWithValue(repo),
          photoPickerProvider.overrideWithValue(picker),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
          photoImageProvider.overrideWith(
            (ref, photo) async => image ?? PhotoBytes(_png),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('UT-PH-12 Windows：「写真を追加」でファイルから選んで付ける', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await show(tester, const PhotoEditor(recordId: 'r1'));

    await tester.tap(find.text('写真を追加'));
    await tester.pumpAndSettle();

    expect(picker.sources, [PhotoSource.gallery]);
    expect(find.byType(PhotoThumb), findsOneWidget);
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('UT-PH-13 Android：カメラかアルバムを選べる。閉じたら何もしない', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await show(tester, const PhotoEditor(recordId: 'r1'));

    await tester.tap(find.text('写真を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('カメラで撮る'));
    await tester.pumpAndSettle();
    expect(picker.sources, [PhotoSource.camera]);

    await tester.tap(find.text('写真を追加'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picker.sources, [PhotoSource.camera]);
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('UT-PH-14 3枚あれば追加のボタンを押せない（AC-03）。外すとまた押せる', (tester) async {
    for (var i = 1; i <= 3; i++) {
      await insertPhoto(db, 'p$i', i);
    }
    await show(tester, const PhotoEditor(recordId: 'r1'));

    final button = find.widgetWithText(OutlinedButton, '写真は3枚までです');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    await tester.tap(find.byTooltip('写真を外す').first);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoThumb), findsNWidgets(2));
    expect(find.text('写真を追加'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-PH-15 異常系：選ばずに閉じたら付けない。読めない画像は案内を出す', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    picker = FakePicker(null);
    await show(tester, const PhotoEditor(recordId: 'r1'));
    await tester.tap(find.text('写真を追加'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumb), findsNothing);
    await close(tester);

    picker = FakePicker(Uint8List.fromList([1]));
    repo.unreadable = true;
    await show(tester, const PhotoEditor(recordId: 'r1'));
    await tester.tap(find.text('写真を追加'));
    await tester.pumpAndSettle();
    expect(find.text('この画像は読み込めませんでした'), findsOneWidget);
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (image, text) in [
    (const PhotoOffline(), 'オンラインで表示できます'),
    (const PhotoNotYetUploaded(), 'まだ届いていません'),
  ]) {
    testWidgets('UT-PH-16 端末になく取れない写真は「$text」と出す（BR-28）', (tester) async {
      await insertPhoto(db, 'p1', 1);
      await show(tester, const PhotoGallery(recordId: 'r1'), image: image);

      expect(find.text(text), findsOneWidget);
      await close(tester);
    });
  }

  testWidgets('UT-PH-17 詳細の写真：画像を出し、写真がなければ何も出さない', (tester) async {
    await show(tester, const PhotoGallery(recordId: 'r1'));
    expect(find.byType(PhotoThumb), findsNothing);
    await close(tester);

    await insertPhoto(db, 'p1', 1);
    await show(tester, const PhotoGallery(recordId: 'r1'));
    expect(find.byType(Image), findsOneWidget);
    await close(tester);
  });
}

/// 1×1 の透明な PNG
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
