import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/presentation/notification_settings_screen.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

/// 通知の許可だけを決められる版（テストの側の差し替え）
class _FakeNotifier implements AppNotifier {
  _FakeNotifier({required this.permitted});

  bool permitted;
  int requests = 0;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    return permitted = true;
  }

  @override
  Future<void> show(AppNotification notification) async {}

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {}

  @override
  Future<void> cancel(int id) async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    return db.close();
  });

  Future<void> show(WidgetTester tester, AppNotifier notifier) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(notifier),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// 保存された設定。見張り（watch）を待つと、テストの偽の時計の中で止まるので、直接読む
  Future<NotificationSettings> saved() async {
    final rows = await db.select(db.appStates).get();
    final values = {for (final r in rows) r.key: r.value};
    return NotificationSettings.parse(
      flagsJson: values[SettingsRepository.notificationsKey],
      reminderHours: values[SettingsRepository.reminderHoursKey],
      method: values[SettingsRepository.anomalyMethodKey],
    );
  }

  testWidgets('UT-NS-05 S-49：種類ごとのオン・オフと判定方式を変えるとすぐ保存する。しきい値を選ぶと入口を出す', (
    tester,
  ) async {
    await show(tester, InAppNotifier());
    for (final kind in NotificationKind.values) {
      expect(find.widgetWithText(SwitchListTile, kind.label), findsOneWidget);
    }
    expect(find.text('しきい値の設定'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, '家族の記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分で決めたしきい値'));
    await tester.pumpAndSettle();

    final s = await saved();
    expect(s.isOn(NotificationKind.family), isFalse);
    expect(s.method, AnomalyMethod.threshold);
    expect(find.text('しきい値の設定'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-NS-06 S-49：記録忘れの時間は 1〜48 だけを保存する（境界値）。記録忘れをオフにすると欄を隠す', (
    tester,
  ) async {
    await show(tester, InAppNotifier());
    final field = find.byType(TextField);

    await tester.enterText(field, '49');
    await tester.pump();
    expect(find.text('1〜48の数字で入れてください'), findsOneWidget);
    expect((await saved()).reminderHours, 10);

    await tester.enterText(field, '48');
    await tester.pumpAndSettle();
    expect(find.text('1〜48の数字で入れてください'), findsNothing);
    expect((await saved()).reminderHours, 48);

    await tester.tap(find.widgetWithText(SwitchListTile, '記録忘れ'));
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    await close(tester);
  });

  testWidgets('UT-NS-07 S-49（Android）：通知が許可されていなければ案内を出し、「許可する」で許可を求めて案内を消す', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final notifier = _FakeNotifier(permitted: false);
    await show(tester, notifier);
    expect(find.text('通知が許可されていません'), findsOneWidget);

    await tester.tap(find.text('許可する'));
    await tester.pumpAndSettle();
    expect(notifier.requests, 1);
    expect(find.text('通知が許可されていません'), findsNothing);
    await close(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'UT-NS-08 S-49（Windows）：許可の案内は出さず、画面の中で知らせる旨を出す。記録にかかわる種類（記録忘れ・お薬の時間・家族の記録）は出さない',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await show(tester, InAppNotifier());
      expect(find.text('通知が許可されていません'), findsNothing);
      expect(find.textContaining('画面の下でお知らせします'), findsOneWidget);
      for (final hidden in ['記録忘れ', 'お薬の時間', '家族の記録']) {
        expect(find.widgetWithText(SwitchListTile, hidden), findsNothing);
      }
      expect(find.byType(TextField), findsNothing);
      for (final shown in ['いつもとの差', '誕生日']) {
        expect(find.widgetWithText(SwitchListTile, shown), findsOneWidget);
      }
      await close(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('UT-NS-09 画面の中で知らせる版（Windows）：知らせた内容を画面の下に出し、開く場所があれば「開く」を出す', (
    tester,
  ) async {
    final notifier = InAppNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          notifierProvider.overrideWithValue(notifier),
        ],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await notifier.show(
      const AppNotification(
        id: 1,
        title: 'ミケのお薬の時間です',
        body: '○○錠 1錠',
        payload: '/login-help',
      ),
    );
    await tester.pump();
    expect(find.text('ミケのお薬の時間です\n○○錠 1錠'), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, '開く'));
    await tester.pumpAndSettle();
    expect(find.text('ログインに困ったら'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await notifier.close();
  });
}
