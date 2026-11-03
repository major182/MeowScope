import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late HouseholdRepository repo;
  final now = DateTime.utc(2026, 11, 3, 10);
  const user = AuthUser(id: 'u1', name: 'はる');

  setUp(() async {
    db = memoryDatabase();
    // ログインした状態にする（ログインは AuthRepository が行う）
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: user.id),
        AppStatesCompanion.insert(key: 'session.userName', value: user.name),
      ]),
    );
    repo = HouseholdRepository(
      db,
      RecordRepository(db, clock: () => now),
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  test('UT-HH-01 ログイン中でも、おうちがまだなければ、セッションは null', () async {
    expect(await repo.watchSession().first, isNull);
  });

  test('UT-HH-02 おうちを作ると、そのおうちとログイン中のユーザーがセッションになる', () async {
    final created = await repo.createHousehold(
      householdName: '  みけ家 ',
      user: user,
    );

    final session = await repo.watchSession().first;
    expect(session, isNotNull);
    expect(session!.householdId, created.householdId);
    expect(session.author.id, created.author.id);
    expect(session.author.name, 'はる');
    // ログアウトして入り直したときのために、ユーザーごとのおうちを覚える
    final remembered = await (db.select(
      db.appStates,
    )..where((s) => s.key.equals('household.u1'))).getSingle();
    expect(remembered.value, created.householdId);
    final household = await db.select(db.households).getSingle();
    expect(household.id, created.householdId);
    expect(household.name, 'みけ家');
    expect(household.createdAt.toUtc(), now);
  });

  test('UT-HH-03 おうちを作ると、標準の8項目も登録する', () async {
    final created = await repo.createHousehold(
      householdName: 'みけ家',
      user: user,
    );

    final types = await RecordRepository(db)
        .watchTypes(created.householdId)
        .first;
    expect(types, hasLength(8));
  });

  test('UT-HH-04 おうちの作成を、同期待ちの変更に残す', () async {
    final created = await repo.createHousehold(
      householdName: 'みけ家',
      user: user,
    );

    final pending = await db.select(db.pendingChanges).getSingle();
    expect(pending.targetTable, 'households');
    expect(pending.rowId, created.householdId);
    expect(pending.userId, created.author.id);
    expect(jsonDecode(pending.payload), {'name': 'みけ家'});
  });

  test('UT-HH-05 セッションの一部が欠けていれば null', () async {
    // おうちはあるが、表示名が欠けている
    await db
        .into(db.appStates)
        .insert(
          AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        );
    await (db.delete(
      db.appStates,
    )..where((s) => s.key.equals('session.userName'))).go();

    expect(await repo.watchSession().first, isNull);
  });
}
