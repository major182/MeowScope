import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../sync/data/sync_engine.dart' show ReceivedRecord;
import '../domain/family_plan.dart';
import '../domain/notification_settings.dart';
import 'notifier.dart';

/// 同期で受け取った家族の記録を知らせる（F-NT-04、BR-08・09）
class FamilyAlerts {
  FamilyAlerts(this._db, this._notifier);

  final AppDatabase _db;
  final AppNotifier _notifier;

  /// [records] のうち、知らせるものを知らせる。出した通知の数を返す
  ///
  /// 設定でオフのとき・Windows では出さない。お別れの猫、消えた猫・項目の記録は知らせない
  Future<int> notify(
    List<ReceivedRecord> records, {
    required NotificationSettings settings,
    required bool android,
  }) async {
    if (records.isEmpty ||
        !settings.shouldNotify(NotificationKind.family, android: android)) {
      return 0;
    }
    final cats = {
      for (final c
          in await (_db.select(_db.cats)..where(
                (c) =>
                    c.id.isIn({for (final r in records) r.catId}) &
                    c.deletedAt.isNull() &
                    c.status.equals('active'),
              ))
              .get())
        c.id: c.name,
    };
    final types = {
      for (final t
          in await (_db.select(_db.recordTypes)..where(
                (t) => t.id.isIn({for (final r in records) r.recordTypeId}),
              ))
              .get())
        t.id: t.name,
    };
    final notifications = familyNotifications([
      for (final r in records)
        if ((cats[r.catId], types[r.recordTypeId]) case (
          final cat?,
          final type?,
        ))
          FamilyRecord(
            id: r.id,
            authorKey: r.authorId ?? r.authorName,
            authorName: r.authorName,
            catName: cat,
            typeName: type,
          ),
    ]);
    for (final n in notifications) {
      await _notifier.show(n);
    }
    return notifications.length;
  }
}

final familyAlertsProvider = Provider<FamilyAlerts>(
  (ref) =>
      FamilyAlerts(ref.watch(databaseProvider), ref.watch(notifierProvider)),
);
