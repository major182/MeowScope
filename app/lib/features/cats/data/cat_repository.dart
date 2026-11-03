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
}
