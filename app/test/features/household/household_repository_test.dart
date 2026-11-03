import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late HouseholdRepository repo;
  final now = DateTime.utc(2026, 11, 3, 10);

  setUp(() {
    db = memoryDatabase();
    repo = HouseholdRepository(
      db,
      RecordRepository(db, clock: () => now),
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  test('UT-HH-01 おうちがまだなければ、セッションは null', () async {
    expect(await repo.watchSession().first, isNull);
  });

  test('UT-HH-02 おうちを作ると、そのおうちと作った人がセッションになる', () async {
    final created = await repo.createHousehold(
      householdName: '  みけ家 ',
      userName: ' はる ',
    );

    final session = await repo.watchSession().first;
    expect(session, isNotNull);
    expect(session!.householdId, created.householdId);
    expect(session.author.id, created.author.id);
    expect(session.author.name, 'はる');
    final household = await db.select(db.households).getSingle();
    expect(household.id, created.householdId);
    expect(household.name, 'みけ家');
    expect(household.createdAt.toUtc(), now);
  });

  test('UT-HH-03 おうちを作ると、標準の8項目も登録する', () async {
    final created = await repo.createHousehold(
      householdName: 'みけ家',
      userName: 'はる',
    );

    final types = await RecordRepository(db)
        .watchTypes(created.householdId)
        .first;
    expect(types, hasLength(8));
  });

  test('UT-HH-04 おうちの作成を、同期待ちの変更に残す', () async {
    final created = await repo.createHousehold(
      householdName: 'みけ家',
      userName: 'はる',
    );

    final pending = await db.select(db.pendingChanges).getSingle();
    expect(pending.targetTable, 'households');
    expect(pending.rowId, created.householdId);
    expect(pending.userId, created.author.id);
    expect(jsonDecode(pending.payload), {'name': 'みけ家'});
  });

  test('UT-HH-05 セッションの一部が欠けていれば null', () async {
    await db
        .into(db.appStates)
        .insert(AppStatesCompanion.insert(key: 'session.userId', value: 'u1'));

    expect(await repo.watchSession().first, isNull);
  });
}
