import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';
import 'package:meowscope/features/settings/presentation/settings_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() {
    // 端末の種類の差し替えは、失敗したときも元に戻す
    debugDefaultTargetPlatformOverride = null;
    return db.close();
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: '/cats', builder: (context, state) => const Text('猫の一覧')),
        GoRoute(
          path: '/record-types',
          builder: (context, state) => const Text('記録項目の一覧'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<String?> storedWeekStart() async =>
      (await (db.select(db.appStates)
                ..where((s) => s.key.equals(SettingsRepository.weekStartKey)))
              .getSingleOrNull())
          ?.value;

  testWidgets('UT-SE-01 「猫の一覧とプロフィール」で猫の一覧へ進む', (tester) async {
    await show(tester);

    await tester.tap(find.text('猫の一覧とプロフィール'));
    await tester.pumpAndSettle();

    expect(find.text('猫の一覧'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-SE-02 「記録項目の設定」で記録項目の一覧へ進む', (tester) async {
    await show(tester);

    await tester.tap(find.text('記録項目の設定'));
    await tester.pumpAndSettle();

    expect(find.text('記録項目の一覧'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-SE-03 まだ作っていない項目は準備中で、押せない', (tester) async {
    // ウィジェットのボタン（Android のみ）を除いた1つを確かめる。おうちの管理・アカウント・同期の状態は作った
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await show(tester);

    for (final label in ['問い合わせ']) {
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, label),
      );
      expect(tile.enabled, isFalse, reason: label);
    }
    expect(find.text('準備中'), findsNWidgets(1));
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('UT-SE-04 ウィジェットのボタンは Android でだけ出す', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await show(tester);
    expect(find.text('ウィジェットのボタン'), findsNothing);
    await close(tester);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await show(tester);
    expect(find.text('ウィジェットのボタン'), findsOneWidget);
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('UT-SE-05 週の始まりは既定で日曜。月曜に切り替えて保存し、日曜に戻せる', (tester) async {
    await show(tester);
    final button = find.byType(SegmentedButton<WeekStart>);
    expect(tester.widget<SegmentedButton<WeekStart>>(button).selected, {
      WeekStart.sunday,
    });

    await tester.tap(find.text('月曜'));
    await tester.pumpAndSettle();
    expect(await storedWeekStart(), 'monday');
    expect(tester.widget<SegmentedButton<WeekStart>>(button).selected, {
      WeekStart.monday,
    });

    await tester.tap(find.text('日曜'));
    await tester.pumpAndSettle();
    expect(await storedWeekStart(), 'sunday');
    await close(tester);
  });
}
