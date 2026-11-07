import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

/// お薬の予定と、その猫（一覧と通知に使う）
class MedicationEntry {
  const MedicationEntry({required this.schedule, required this.cat});

  final MedicationScheduleRow schedule;
  final CatRow cat;
}

/// お薬の予定（S-50、F-MD-02、BR-06）。おうちのもので、同期で家族と共有する
class MedicationRepository {
  MedicationRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 薬の名前と量の長さの上限（DB 設計書）
  static const maxLength = 20;

  /// おうちの予定を、猫の登録順・時刻の順に見張る。削除した予定と、削除した猫の予定は除く
  Stream<List<MedicationEntry>> watchSchedules(String householdId) {
    final q =
        _db.select(_db.medicationSchedules).join([
            innerJoin(
              _db.cats,
              _db.cats.id.equalsExp(_db.medicationSchedules.catId),
            ),
          ])
          ..where(
            _db.medicationSchedules.householdId.equals(householdId) &
                _db.medicationSchedules.deletedAt.isNull() &
                _db.cats.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm(expression: _db.cats.createdAt),
            OrderingTerm(expression: _db.cats.id),
            OrderingTerm(expression: _db.medicationSchedules.timeOfDay),
            OrderingTerm(expression: _db.medicationSchedules.createdAt),
          ]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          MedicationEntry(
            schedule: r.readTable(_db.medicationSchedules),
            cat: r.readTable(_db.cats),
          ),
      ],
    );
  }

  /// 1つの予定を見張る（編集の画面）。削除していれば null
  Stream<MedicationScheduleRow?> watchSchedule(String id) => (_db.select(
    _db.medicationSchedules,
  )..where((m) => m.id.equals(id) & m.deletedAt.isNull())).watchSingleOrNull();

  /// 予定を追加する。追加した予定の ID を返す
  Future<String> add({
    required String householdId,
    required String userId,
    required String catId,
    required String name,
    String? dose,
    required String timeOfDay,
    bool enabled = true,
  }) {
    final id = _uuid.v4();
    final now = _clock().toUtc();
    return _db.transaction(() async {
      await _db
          .into(_db.medicationSchedules)
          .insert(
            MedicationSchedulesCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              householdId: householdId,
              catId: catId,
              name: name.trim(),
              dose: Value(_blankToNull(dose)),
              timeOfDay: timeOfDay,
              enabled: Value(enabled),
            ),
          );
      await _pending(userId, id);
      return id;
    });
  }

  /// 予定を変える
  Future<void> update({
    required String id,
    required String userId,
    required String catId,
    required String name,
    String? dose,
    required String timeOfDay,
    required bool enabled,
  }) => _write(
    id,
    userId,
    MedicationSchedulesCompanion(
      catId: Value(catId),
      name: Value(name.trim()),
      dose: Value(_blankToNull(dose)),
      timeOfDay: Value(timeOfDay),
      enabled: Value(enabled),
    ),
  );

  /// オン・オフだけを変える（一覧のスイッチ）
  Future<void> setEnabled({
    required String id,
    required String userId,
    required bool enabled,
  }) =>
      _write(id, userId, MedicationSchedulesCompanion(enabled: Value(enabled)));

  /// 予定を削除する（削除の印を付けて同期する。BR-11）
  Future<void> delete({required String id, required String userId}) => _write(
    id,
    userId,
    MedicationSchedulesCompanion(deletedAt: Value(_clock().toUtc())),
  );

  Future<void> _write(
    String id,
    String userId,
    MedicationSchedulesCompanion changes,
  ) => _db.transaction(() async {
    final count =
        await (_db.update(_db.medicationSchedules)
              ..where((m) => m.id.equals(id) & m.deletedAt.isNull()))
            .write(changes.copyWith(updatedAt: Value(_clock().toUtc())));
    if (count == 0) {
      throw StateError('お薬の予定が見つかりません: $id');
    }
    await _pending(userId, id);
  });

  /// 同期待ちに入れる。送るときは行の今の内容を丸ごと送る（SyncEngine）
  Future<void> _pending(String userId, String id) => _db
      .into(_db.pendingChanges)
      .insert(
        PendingChangesCompanion.insert(
          userId: userId,
          targetTable: 'medication_schedules',
          rowId: id,
          operation: 'upsert',
          payload: jsonEncode({'id': id}),
        ),
      );

  static String? _blankToNull(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
