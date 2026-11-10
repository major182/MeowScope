import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/notifications/data/permission_prompt.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late RecordingNotifier notifier;

  setUp(() {
    db = memoryDatabase();
    notifier = RecordingNotifier()..permitted = false;
  });
  tearDown(() => db.close());

  PermissionPrompt prompt({bool android = true}) =>
      PermissionPrompt(db, notifier, android: android);

  const all = NotificationSettings();
  final reminderOff = const NotificationSettings().toggled(
    NotificationKind.reminder,
    false,
  );

  group('UT-NP-01 通知の許可を、初めて必要になったときに求める（デシジョンテーブル）', () {
    test('Android・オン・未許可・まだ求めていない：求めて、求めたことを覚える', () async {
      expect(
        await prompt().askIfNeeded(all, {NotificationKind.medication}),
        isTrue,
      );
      expect(notifier.requests, 1);
    });

    test('2回目は求めない（断られても、あとは S-49 の案内に任せる）', () async {
      await prompt().askIfNeeded(all, {NotificationKind.medication});
      notifier.permitted = false;
      expect(
        await prompt().askIfNeeded(all, {NotificationKind.birthday}),
        isFalse,
      );
      expect(notifier.requests, 1);
    });

    test('もう許可されていれば求めず、求めたことにもしない', () async {
      notifier.permitted = true;
      expect(
        await prompt().askIfNeeded(all, {NotificationKind.medication}),
        isFalse,
      );
      notifier.permitted = false;
      expect(
        await prompt().askIfNeeded(all, {NotificationKind.medication}),
        isTrue,
      );
    });

    test('その種類の通知がすべてオフなら求めない。1つでもオンなら求める', () async {
      expect(
        await prompt().askIfNeeded(reminderOff, {NotificationKind.reminder}),
        isFalse,
      );
      expect(
        await prompt().askIfNeeded(reminderOff, {
          NotificationKind.reminder,
          NotificationKind.anomaly,
        }),
        isTrue,
      );
    });

    test('Windows では求めない（BR-09）', () async {
      expect(
        await prompt(android: false)
            .askIfNeeded(all, {NotificationKind.birthday}),
        isFalse,
      );
      expect(notifier.requests, 0);
    });
  });

  test('UT-NP-02 通知の設定を1回だけ読む：未設定なら既定、保存した値を返す', () async {
    final repo = SettingsRepository(db);
    expect(
      (await repo.readNotificationSettings()).isOn(NotificationKind.reminder),
      isTrue,
    );
    await repo.setNotificationSettings(reminderOff);
    final read = await repo.readNotificationSettings();
    expect(read.isOn(NotificationKind.reminder), isFalse);
    expect(read.isOn(NotificationKind.medication), isTrue);
  });
}
