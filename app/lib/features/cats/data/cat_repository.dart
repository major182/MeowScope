import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

/// 猫の性別。未選択は null とする（BR-24）
enum CatSex {
  male('男の子'),
  female('女の子'),
  unknown('不明');

  const CatSex(this.label);

  final String label;
}

/// 猫の登録。書き込みは同期待ちの変更も同時に残す
class CatRepository {
  CatRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 猫を登録する。名前以外は任意（BR-24）。登録した猫の ID を返す
  Future<String> addCat({
    required String householdId,
    required String userId,
    required String name,
    DateTime? birthDate,
    CatSex? sex,
    String? conditions,
  }) {
    final id = _uuid.v4();
    final now = _clock().toUtc();
    final trimmedName = name.trim();
    final trimmedConditions = conditions?.trim();
    final storedConditions = (trimmedConditions?.isEmpty ?? true)
        ? null
        : trimmedConditions;
    final birth = birthDate == null
        ? null
        : DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
    return _db.transaction(() async {
      await _db
          .into(_db.cats)
          .insert(
            CatsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              householdId: householdId,
              name: trimmedName,
              birthDate: Value(birth),
              sex: Value(sex?.name),
              conditions: Value(storedConditions),
            ),
          );
      await _db
          .into(_db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: userId,
              targetTable: 'cats',
              rowId: id,
              operation: 'upsert',
              payload: jsonEncode({
                'householdId': householdId,
                'name': trimmedName,
                'birthDate': birth?.toIso8601String(),
                'sex': sex?.name,
                'conditions': storedConditions,
              }),
            ),
          );
      return id;
    });
  }

  /// 猫1匹を見張る。削除済みや存在しなければ null
  Stream<CatRow?> watchCat(String id) => (_db.select(
    _db.cats,
  )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).watchSingleOrNull();

  /// プロフィールを更新する。名前以外は任意（BR-24）
  Future<void> updateCat({
    required String id,
    required String userId,
    required String name,
    DateTime? birthDate,
    CatSex? sex,
    String? conditions,
  }) {
    final trimmedName = name.trim();
    final trimmedConditions = conditions?.trim();
    final storedConditions = (trimmedConditions?.isEmpty ?? true)
        ? null
        : trimmedConditions;
    final birth = birthDate == null
        ? null
        : DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
    return _write(
      id,
      userId,
      CatsCompanion(
        name: Value(trimmedName),
        birthDate: Value(birth),
        sex: Value(sex?.name),
        conditions: Value(storedConditions),
      ),
      {
        'name': trimmedName,
        'birthDate': birth?.toIso8601String(),
        'sex': sex?.name,
        'conditions': storedConditions,
      },
    );
  }

  /// いつもとの差のしきい値を保存する（S-47、BR-20）。[thresholds] は DB 設計書の形の JSON（空なら null）
  Future<void> setThresholds({
    required String id,
    required String userId,
    required String? thresholds,
  }) => _write(
    id,
    userId,
    CatsCompanion(anomalyThresholds: Value(thresholds)),
    {'anomalyThresholds': thresholds},
  );

  /// お別れにする、または取り消す（BR-25）。記録はそのまま残す
  Future<void> setFarewell({
    required String id,
    required String userId,
    required bool farewell,
  }) {
    final status = farewell ? 'farewell' : 'active';
    return _write(id, userId, CatsCompanion(status: Value(status)), {
      'status': status,
    });
  }

  /// 猫とその猫の記録を消す（BR-27）。削除も更新として同期する（BR-11）
  Future<void> deleteCat({required String id, required String userId}) {
    final now = _clock().toUtc();
    return _db.transaction(() async {
      final count =
          await (_db.update(
            _db.cats,
          )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).write(
            CatsCompanion(updatedAt: Value(now), deletedAt: Value(now)),
          );
      if (count == 0) {
        throw StateError('猫が見つかりません: $id');
      }
      final records = await (_db.select(
        _db.records,
      )..where((r) => r.catId.equals(id) & r.deletedAt.isNull())).get();
      await (_db.update(
        _db.records,
      )..where((r) => r.catId.equals(id) & r.deletedAt.isNull())).write(
        RecordsCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
      final payload = jsonEncode({'deletedAt': now.toIso8601String()});
      await _db.batch((b) {
        b.insertAll(_db.pendingChanges, [
          PendingChangesCompanion.insert(
            userId: userId,
            targetTable: 'cats',
            rowId: id,
            operation: 'delete',
            payload: payload,
          ),
          for (final r in records)
            PendingChangesCompanion.insert(
              userId: userId,
              targetTable: 'records',
              rowId: r.id,
              operation: 'delete',
              payload: payload,
            ),
        ]);
      });
    });
  }

  /// 猫の行を更新し、同期待ちの変更を残す。猫がいなければ StateError
  Future<void> _write(
    String id,
    String userId,
    CatsCompanion values,
    Map<String, Object?> payload,
  ) {
    final now = _clock().toUtc();
    return _db.transaction(() async {
      final count =
          await (_db.update(_db.cats)
                ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
              .write(values.copyWith(updatedAt: Value(now)));
      if (count == 0) {
        throw StateError('猫が見つかりません: $id');
      }
      await _db
          .into(_db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: userId,
              targetTable: 'cats',
              rowId: id,
              operation: 'upsert',
              payload: jsonEncode({
                ...payload,
                'updatedAt': now.toIso8601String(),
              }),
            ),
          );
    });
  }
}

/// 年齢の表示。1歳以上は「N歳」、1歳未満は「Nか月」。生年月日がないか未来なら null。
/// 生年月日は保存した UTC の年月日で渡す
String? ageLabel(DateTime? birthDate, DateTime today) {
  if (birthDate == null) {
    return null;
  }
  var months =
      (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  // 今月の誕生日の前なら、まだ1か月足りない
  if (today.day < birthDate.day) {
    months--;
  }
  if (months < 0) {
    return null;
  }
  return months >= 12 ? '${months ~/ 12}歳' : '$monthsか月';
}
