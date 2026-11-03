import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/cats/data/cat_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late CatRepository cats;
  late RecordRepository records;
  const author = Author(id: 'u1', name: 'はる');

  setUp(() async {
    db = memoryDatabase();
    now = DateTime(2026, 11, 3, 10);
    cats = CatRepository(db, clock: () => now);
    records = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await records.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  Future<List<PendingChangeRow>> pending() =>
      db.select(db.pendingChanges).get();

  Future<String> addRecord(String catId) async {
    final type = (await records.watchTypes('h1').first).first;
    return records.addRecord(
      catId: catId,
      recordTypeId: type.id,
      author: author,
    );
  }

  test('UT-CP-01 猫1匹を返す。存在しなければ null', () async {
    expect((await cats.watchCat('c1').first)!.name, 'ミケ');
    expect(await cats.watchCat('none').first, isNull);
  });

  test('UT-CP-02 プロフィールを更新し、同期待ちに残す。名前と持病の前後の空白を除く', () async {
    await cats.updateCat(
      id: 'c1',
      userId: 'u1',
      name: ' ミケコ ',
      birthDate: DateTime(2023, 4, 5, 18),
      sex: CatSex.female,
      conditions: ' 腎臓 ',
    );

    final cat = (await cats.watchCat('c1').first)!;
    expect(cat.name, 'ミケコ');
    expect(cat.birthDate!.isAtSameMomentAs(DateTime.utc(2023, 4, 5)), isTrue);
    expect(cat.sex, 'female');
    expect(cat.conditions, '腎臓');
    final change = (await pending()).single;
    expect(change.operation, 'upsert');
    expect(jsonDecode(change.payload)['name'], 'ミケコ');
  });

  test('UT-CP-03 任意の項目を空に戻せる（BR-24）', () async {
    await cats.updateCat(
      id: 'c1',
      userId: 'u1',
      name: 'ミケ',
      birthDate: DateTime(2023, 4, 5),
      sex: CatSex.male,
      conditions: 'あり',
    );
    await cats.updateCat(id: 'c1', userId: 'u1', name: 'ミケ', conditions: ' ');

    final cat = (await cats.watchCat('c1').first)!;
    expect(cat.birthDate, isNull);
    expect(cat.sex, isNull);
    expect(cat.conditions, isNull);
  });

  test('UT-CP-04 異常系：存在しない猫は更新せず、同期待ちも残さない', () async {
    await expectLater(
      cats.updateCat(id: 'none', userId: 'u1', name: 'x'),
      throwsStateError,
    );
    expect(await pending(), isEmpty);
  });

  test('UT-CP-05 お別れにすると記録の対象から外れ、記録は残る。取り消すと戻る（BR-25）', () async {
    await addRecord('c1');

    await cats.setFarewell(id: 'c1', userId: 'u1', farewell: true);
    expect((await cats.watchCat('c1').first)!.status, 'farewell');
    expect((await records.watchActiveCats('h1').first).map((c) => c.id), [
      'c2',
    ]);
    expect(await records.watchDay('h1', now).first, hasLength(1));

    await cats.setFarewell(id: 'c1', userId: 'u1', farewell: false);
    expect((await cats.watchCat('c1').first)!.status, 'active');
    expect(
      (await pending())
          .where((p) => p.targetTable == 'cats')
          .map((p) => jsonDecode(p.payload)['status']),
      ['farewell', 'active'],
    );
  });

  test('UT-CP-06 削除すると、その猫と記録だけを消し、それぞれ同期待ちに残す（BR-27、BR-11）', () async {
    final r1 = await addRecord('c1');
    final r2 = await addRecord('c1');
    final other = await addRecord('c2');
    await db.delete(db.pendingChanges).go();

    await cats.deleteCat(id: 'c1', userId: 'u1');

    expect(await cats.watchCat('c1').first, isNull);
    final rows = {
      for (final r in await db.select(db.records).get()) r.id: r.deletedAt,
    };
    expect(rows[r1], isNotNull);
    expect(rows[r2], isNotNull);
    expect(rows[other], isNull);
    final changes = await pending();
    expect(changes.map((c) => (c.targetTable, c.operation)).toSet(), {
      ('cats', 'delete'),
      ('records', 'delete'),
    });
    expect(
      changes
          .where((c) => c.targetTable == 'records')
          .map((c) => c.rowId)
          .toSet(),
      {r1, r2},
    );
  });

  test('UT-CP-07 異常系：削除済みの猫はもう一度削除できない', () async {
    await cats.deleteCat(id: 'c1', userId: 'u1');

    await expectLater(cats.deleteCat(id: 'c1', userId: 'u1'), throwsStateError);
    expect(await pending(), hasLength(1));
  });

  group('ageLabel', () {
    final today = DateTime(2026, 11, 3);

    test('UT-CP-08 境界値：1歳の誕生日の前日は11か月、当日は1歳', () {
      expect(ageLabel(DateTime(2025, 11, 4), today), '11か月');
      expect(ageLabel(DateTime(2025, 11, 3), today), '1歳');
    });

    test('UT-CP-09 生まれた日は0か月、3年後は3歳', () {
      expect(ageLabel(today, today), '0か月');
      expect(ageLabel(DateTime(2023, 1, 1), today), '3歳');
    });

    test('UT-CP-10 生年月日がない／未来なら出さない', () {
      expect(ageLabel(null, today), isNull);
      expect(ageLabel(DateTime(2026, 11, 4), today), isNull);
    });
  });
}
