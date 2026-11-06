import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  group('UT-NS-01 保存した値から作る', () {
    test('未設定：すべてオン、記録忘れは10時間、判定は統計', () {
      final s = NotificationSettings.parse();
      expect(NotificationKind.values.every(s.isOn), isTrue);
      expect(s.reminderHours, 10);
      expect(s.method, AnomalyMethod.statistical);
    });

    test('一部の種類だけオフ。ない種類はオン', () {
      final s = NotificationSettings.parse(flagsJson: '{"family":false}');
      expect(s.isOn(NotificationKind.family), isFalse);
      expect(s.isOn(NotificationKind.birthday), isTrue);
    });

    test('壊れた値：JSON が壊れていればすべてオン、知らない判定方式は統計、範囲外の時間は既定', () {
      final s = NotificationSettings.parse(
        flagsJson: '{壊れた',
        reminderHours: '49',
        method: 'ai',
      );
      expect(NotificationKind.values.every(s.isOn), isTrue);
      expect(s.reminderHours, 10);
      expect(s.method, AnomalyMethod.statistical);
    });
  });

  test('UT-NS-02 境界値：記録忘れの時間は 1〜48（0・49 と数字でない値は文を出す）', () {
    expect(NotificationSettings.validateHours('1'), isNull);
    expect(NotificationSettings.validateHours(' 48 '), isNull);
    for (final bad in ['0', '49', '', 'あ']) {
      expect(NotificationSettings.validateHours(bad), '1〜48の数字で入れてください');
    }
  });

  test('UT-NS-03 保存の形：すべての種類のオン・オフを書き、変えた種類だけが変わる', () {
    final s = const NotificationSettings().toggled(
      NotificationKind.anomaly,
      false,
    );
    expect(s.flags, {
      'medication': true,
      'anomaly': false,
      'reminder': true,
      'family': true,
      'birthday': true,
    });
  });

  group('UT-NS-04 端末への保存', () {
    late AppDatabase db;
    setUp(() => db = memoryDatabase());
    tearDown(() => db.close());

    test('保存すると見張りに届き、ユーザーがいれば同期待ちに入る。いなければ入れない', () async {
      final repo = SettingsRepository(db);
      final value = const NotificationSettings(
        reminderHours: 6,
        method: AnomalyMethod.threshold,
      ).toggled(NotificationKind.birthday, false);

      await repo.setNotificationSettings(value);
      expect(await db.select(db.pendingChanges).get(), isEmpty);
      await repo.setNotificationSettings(value, userId: 'u1');

      final watched = await repo.watchNotificationSettings().first;
      expect(watched.reminderHours, 6);
      expect(watched.method, AnomalyMethod.threshold);
      expect(watched.isOn(NotificationKind.birthday), isFalse);
      final pending = await db.select(db.pendingChanges).getSingle();
      expect(pending.targetTable, 'user_settings');
      expect(pending.rowId, 'u1');
    });
  });
}
