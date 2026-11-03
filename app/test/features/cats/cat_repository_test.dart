import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/cats/data/cat_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late CatRepository repo;
  final now = DateTime.utc(2026, 11, 3, 10);

  setUp(() async {
    db = memoryDatabase();
    repo = CatRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
  });

  tearDown(() => db.close());

  Future<CatRow> onlyCat() => db.select(db.cats).getSingle();

  test('UT-CT-01 名前だけで登録でき、任意の項目は空のまま', () async {
    await repo.addCat(householdId: 'h1', userId: 'u1', name: ' ミケ ');

    final cat = await onlyCat();
    expect(cat.name, 'ミケ');
    expect(cat.birthDate, isNull);
    expect(cat.sex, isNull);
    expect(cat.conditions, isNull);
    expect(cat.status, 'active');
    expect(cat.createdAt.toUtc(), now);
  });

  test('UT-CT-02 生年月日・性別・持病を保存する。生年月日は日付だけを残す', () async {
    await repo.addCat(
      householdId: 'h1',
      userId: 'u1',
      name: 'タマ',
      birthDate: DateTime(2021, 4, 1, 15, 30),
      sex: CatSex.female,
      conditions: ' 腎臓 ',
    );

    final cat = await onlyCat();
    expect(cat.birthDate!.toUtc(), DateTime.utc(2021, 4, 1));
    expect(cat.sex, 'female');
    expect(cat.conditions, '腎臓');
  });

  test('UT-CT-03 持病が空白だけなら空として保存する', () async {
    await repo.addCat(
      householdId: 'h1',
      userId: 'u1',
      name: 'ミケ',
      conditions: '   ',
    );

    expect((await onlyCat()).conditions, isNull);
  });

  test('UT-CT-04 登録を同期待ちの変更に残す', () async {
    final id = await repo.addCat(
      householdId: 'h1',
      userId: 'u1',
      name: 'ミケ',
      sex: CatSex.unknown,
    );

    final pending = await db.select(db.pendingChanges).getSingle();
    expect(pending.targetTable, 'cats');
    expect(pending.rowId, id);
    expect(pending.userId, 'u1');
    expect(jsonDecode(pending.payload), {
      'householdId': 'h1',
      'name': 'ミケ',
      'birthDate': null,
      'sex': 'unknown',
      'conditions': null,
    });
  });

  test('UT-CT-05 異常系：存在しないおうちには登録せず、同期待ちも残さない', () async {
    await expectLater(
      repo.addCat(householdId: 'none', userId: 'u1', name: 'ミケ'),
      throwsA(anything),
    );

    expect(await db.select(db.cats).get(), isEmpty);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
  });
}
