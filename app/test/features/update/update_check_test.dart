import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/presentation/login_screen.dart';
import 'package:meowscope/features/settings/presentation/settings_screen.dart';
import 'package:meowscope/features/update/data/update_installer.dart';
import 'package:meowscope/features/update/data/update_repository.dart';
import 'package:meowscope/features/update/domain/app_release.dart';
import 'package:meowscope/features/update/presentation/update_runner.dart';
import 'package:meowscope/features/update/update_providers.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

const _sha = 'abababababababababababababababababababababababababababababababab';

Map<String, Object> releaseBody({int build = 2, String version = '1.0.1'}) => {
  'version': version,
  'buildNumber': build,
  'sha256': _sha,
  'sizeBytes': 100,
};

const installed = InstalledVersion(version: '1.0.0', buildNumber: 2);

/// 決めた進み具合を渡してから、決めた結果を返す偽の部品
class FakeInstaller implements UpdateInstaller {
  FakeInstaller({this.fail = false});

  final bool fail;
  var calls = 0;

  @override
  Future<void> install(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    calls++;
    onProgress(0.45);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (fail) throw const UpdateFailed('download');
  }
}

void main() {
  late FakeServer server;
  late MemoryTokenStore tokens;
  late AppDatabase db;

  setUp(() {
    server = FakeServer();
    tokens = MemoryTokenStore();
    db = memoryDatabase();
  });
  tearDown(() => db.close());

  UpdateRepository repository({
    String platform = 'android',
    Future<InstalledVersion> Function()? current,
  }) => UpdateRepository(
    fakeApiClient(server, tokens),
    current ?? () async => installed,
    platform: platform,
  );

  group('UT-UP-02 新しい版かどうか（BR-34）', () {
    test('ビルド番号の境界値：同じ・小さいは最新、1つ大きいと知らせる', () async {
      for (final (build, newer) in [(1, false), (2, false), (3, true)]) {
        server.on(
          'GET',
          '/app-releases/android/latest',
          (_) => FakeResponse(200, releaseBody(build: build)),
        );
        final result = await repository().check();
        expect(result is UpdateAvailable, newer, reason: 'build $build');
      }
    });

    test('版の文字ではなくビルド番号で比べる', () async {
      server.on(
        'GET',
        '/app-releases/android/latest',
        (_) => FakeResponse(200, releaseBody(build: 2, version: '9.9.9')),
      );
      expect(await repository().check(), isA<UpToDate>());
    });

    test('Windows は windows の版を聞く', () async {
      server.on(
        'GET',
        '/app-releases/windows/latest',
        (_) => FakeResponse(200, releaseBody(build: 3)),
      );
      final result = await repository(platform: 'windows').check();
      expect((result as UpdateAvailable).release.version, '1.0.1');
      expect(result.installed.version, '1.0.0');
    });
  });

  group('UT-UP-03 確かめられないとき（BR-33：アプリはそのまま使える）', () {
    test('版が置かれていない（404）は最新とする', () async {
      expect(await repository().check(), isA<UpToDate>());
    });

    test('つながらない・サーバーの異常・形の違う応答・今の版が読めないは失敗', () async {
      server.on(
        'GET',
        '/app-releases/android/latest',
        (_) => const FakeResponse.offline(),
      );
      expect(await repository().check(), isA<UpdateCheckFailed>());
      server.on(
        'GET',
        '/app-releases/android/latest',
        (_) => const FakeResponse(500, {'code': 'INTERNAL_ERROR'}),
      );
      expect(await repository().check(), isA<UpdateCheckFailed>());
      server.on(
        'GET',
        '/app-releases/android/latest',
        (_) => const FakeResponse(200, {'version': 1}),
      );
      expect(await repository().check(), isA<UpdateCheckFailed>());
      server.on(
        'GET',
        '/app-releases/android/latest',
        (_) => FakeResponse(200, releaseBody(build: 3)),
      );
      expect(
        await repository(current: () async => throw Exception('no')).check(),
        isA<UpdateCheckFailed>(),
      );
    });
  });

  Future<FakeInstaller> showRunner(
    WidgetTester tester, {
    int build = 3,
    FakeInstaller? installer,
  }) async {
    server.on(
      'GET',
      '/app-releases/android/latest',
      (_) => FakeResponse(200, releaseBody(build: build)),
    );
    final fake = installer ?? FakeInstaller();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          installedVersionProvider.overrideWith((ref) async => installed),
          updateInstallerProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UpdateRunner(child: Text('ホーム'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  group('UT-UP-04 起動したときのお知らせ（S-51）', () {
    testWidgets('新しい版があれば、版と今の版を出す', (tester) async {
      await showRunner(tester);
      expect(find.text('新しい版があります'), findsOneWidget);
      expect(find.textContaining('Ver.1.0.1 に更新できます'), findsOneWidget);
      expect(find.textContaining('（今の版 Ver.1.0.0）'), findsOneWidget);
    });

    testWidgets('最新なら出さない', (tester) async {
      await showRunner(tester, build: 2);
      expect(find.text('新しい版があります'), findsNothing);
      expect(find.text('ホーム'), findsOneWidget);
    });

    testWidgets('「5分後に知らせる」：閉じて、4分59秒では出さず、5分で出す', (tester) async {
      await showRunner(tester);
      await tester.tap(find.text('5分後に知らせる'));
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsNothing);
      await tester.pump(const Duration(minutes: 4, seconds: 59));
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsOneWidget);
    });

    testWidgets('戻るボタンも「5分後に知らせる」と同じ', (tester) async {
      await showRunner(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsNothing);
      await tester.pump(UpdatePromptController.remindAfter);
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsOneWidget);
    });
  });

  group('UT-UP-05 「今すぐ更新」', () {
    testWidgets('進み具合を出し、その間はボタンを出さない', (tester) async {
      final fake = await showRunner(tester);
      await tester.tap(find.text('今すぐ更新'));
      await tester.pump();
      expect(fake.calls, 1);
      expect(find.text('更新を取ってきています（45%）'), findsOneWidget);
      expect(find.text('5分後に知らせる'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // 入れ方の画面から戻った（取りやめた）ら閉じる
      expect(find.text('新しい版があります'), findsNothing);
    });

    testWidgets('失敗したら閉じて案内を出し、アプリはそのまま使える。5分後には出さない', (tester) async {
      await showRunner(tester, installer: FakeInstaller(fail: true));
      await tester.tap(find.text('今すぐ更新'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsNothing);
      expect(find.text('更新を取ってこられませんでした。もう一度試してください'), findsOneWidget);
      expect(find.text('ホーム'), findsOneWidget);
      await tester.pump(UpdatePromptController.remindAfter);
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsNothing);
    });
  });

  Future<void> showSettings(WidgetTester tester, FakeHandler handler) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server.on('GET', '/app-releases/android/latest', handler);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const UpdateRunner(child: SettingsScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          installedVersionProvider.overrideWith((ref) async => installed),
          updateInstallerProvider.overrideWithValue(FakeInstaller()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('UT-UP-06 設定の「アプリの更新」（S-40）', () {
    testWidgets('今の版を出し、最新なら「最新の版です」', (tester) async {
      await showSettings(tester, (_) => FakeResponse(200, releaseBody()));
      expect(find.text('Ver.1.0.0'), findsOneWidget);
      await tester.tap(find.text('更新を確かめる'));
      await tester.pumpAndSettle();
      expect(find.text('最新の版です'), findsOneWidget);
    });

    testWidgets('確かめられなければ通信を確かめる案内', (tester) async {
      await showSettings(tester, (_) => const FakeResponse.offline());
      await tester.tap(find.text('更新を確かめる'));
      await tester.pumpAndSettle();
      expect(find.text('更新を確かめられませんでした。通信を確かめてください'), findsOneWidget);
    });

    testWidgets('新しい版があれば S-51 を出す', (tester) async {
      var build = 2;
      await showSettings(
        tester,
        (_) => FakeResponse(200, releaseBody(build: build)),
      );
      build = 3;
      await tester.tap(find.text('更新を確かめる'));
      await tester.pumpAndSettle();
      expect(find.text('新しい版があります'), findsOneWidget);
    });
  });

  group('UT-UP-07 ログインの画面の版（S-01、F-UP-03）', () {
    testWidgets('ビルド番号を出さずに今の版を出す。読めなければ空', (tester) async {
      Future<void> show(Future<InstalledVersion> Function() read) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              databaseProvider.overrideWithValue(db),
              installedVersionProvider.overrideWith((ref) => read()),
            ],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(() async => installed);
      expect(find.text('Ver.1.0.0'), findsOneWidget);
      expect(find.textContaining('+2'), findsNothing);
      await show(() async => throw Exception('no'));
      expect(find.textContaining('Ver.'), findsNothing);
    });
  });
}
