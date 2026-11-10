import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../domain/notification_settings.dart';
import 'notifier.dart';

/// 通知の許可を、通知が初めて必要になったときに求める（Android。画面設計書 4章）
///
/// お薬の予定・生年月日のある猫の保存や、記録をしたときに呼ぶ。
/// その種類の通知がオンで、まだ許可されておらず、この端末でまだ求めていないときだけ、OS の確認を出す。
/// 断られたら、あとは通知の設定（S-49）の案内に任せる（何度も求めない）
class PermissionPrompt {
  PermissionPrompt(this._db, this._notifier, {required this.android});

  final AppDatabase _db;
  final AppNotifier _notifier;
  final bool android;

  /// 求めたことを覚えておく端末の状態のキー
  static const askedKey = 'notifications.permissionAsked';

  /// [kinds] のどれかがオンなら、必要に応じて許可を求める。OS の確認を出したら true
  Future<bool> askIfNeeded(
    NotificationSettings settings,
    Set<NotificationKind> kinds,
  ) async {
    if (!android || !kinds.any(settings.isOn)) {
      return false;
    }
    final asked = await (_db.select(
      _db.appStates,
    )..where((s) => s.key.equals(askedKey))).getSingleOrNull();
    if (asked != null || await _notifier.isPermitted()) {
      return false;
    }
    await _db
        .into(_db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(key: askedKey, value: 'true'),
        );
    await _notifier.requestPermission();
    return true;
  }
}

final permissionPromptProvider = Provider<PermissionPrompt>(
  (ref) => PermissionPrompt(
    ref.watch(databaseProvider),
    ref.watch(notifierProvider),
    android: defaultTargetPlatform == TargetPlatform.android,
  ),
);

/// 画面から呼ぶ。設定を読んで、[kinds] の通知のために許可を求める。失敗しても保存などの操作は止めない
Future<void> askNotificationPermission(
  WidgetRef ref,
  Set<NotificationKind> kinds,
) async {
  try {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .readNotificationSettings();
    await ref.read(permissionPromptProvider).askIfNeeded(settings, kinds);
  } on Object catch (e) {
    await ref
        .read(appLogProvider)
        .record('warning', '通知の許可の確認に失敗：${e.runtimeType}');
  }
}
