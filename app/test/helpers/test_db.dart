import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meowscope/core/db/app_database.dart';

/// メモリー上の DB を作る。テストごとに空の状態から始まる
AppDatabase memoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

final testTime = DateTime.utc(2026, 11, 2, 9, 30);

/// おうちを1つ登録する
Future<void> addHousehold(AppDatabase db, String id) => db
    .into(db.households)
    .insert(
      HouseholdsCompanion.insert(
        id: id,
        createdAt: testTime,
        updatedAt: testTime,
        name: 'みけ家',
      ),
    );

/// 猫を1匹登録する
Future<void> addCat(
  AppDatabase db, {
  required String id,
  required String householdId,
  required String name,
  String status = 'active',
  DateTime? deletedAt,
  DateTime? createdAt,
}) => db
    .into(db.cats)
    .insert(
      CatsCompanion.insert(
        id: id,
        createdAt: createdAt ?? testTime,
        updatedAt: testTime,
        householdId: householdId,
        name: name,
        status: Value(status),
        deletedAt: Value(deletedAt),
      ),
    );
