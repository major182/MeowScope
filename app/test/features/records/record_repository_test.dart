import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late RecordRepository repo;
  const author = Author(id: 'u1', name: 'はる');

  setUp(() async {
    db = memoryDatabase();
    now = DateTime(2026, 11, 2, 9, 30);
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
  });

  tearDown(() => db.close());

  Future<RecordTypeRow> firstType(String householdId) async =>
      (await repo.watchTypes(householdId).first).first;

  group('addStandardTypes', () {
    test('UT-RC-05 標準の8項目を並び順どおりに登録する', () async {
      await repo.addStandardTypes('h1');

      final types = await repo.watchTypes('h1').first;
      expect(types.map((t) => t.kind), RecordKind.values.map((k) => k.name));
      expect(types.map((t) => t.icon), RecordKind.values.map((k) => k.icon));
    });

    test('UT-RC-06 2回呼んでも重複して登録しない', () async {
      await repo.addStandardTypes('h1');
      await repo.addStandardTypes('h1');

      expect(await repo.watchTypes('h1').first, hasLength(8));
    });

    test('UT-RC-07 独自の項目だけがあるおうちには、標準の項目を登録する', () async {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: 'custom1',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: '通院',
              kind: RecordKind.custom,
              sortOrder: const Value(99),
            ),
          );

      await repo.addStandardTypes('h1');

      expect(await repo.watchTypes('h1').first, hasLength(9));
    });
  });

  group('watchTypes', () {
    test('UT-RC-08 他のおうちの項目と削除済みの項目は含めない', () async {
      await repo.addStandardTypes('h1');
      await repo.addStandardTypes('h2');
      final food = await firstType('h1');
      await (db.update(db.recordTypes)..where((t) => t.id.equals(food.id)))
          .write(RecordTypesCompanion(deletedAt: Value(testTime)));

      final types = await repo.watchTypes('h1').first;

      expect(types, hasLength(7));
      expect(types.every((t) => t.householdId == 'h1'), isTrue);
    });
  });

  group('watchActiveCats', () {
    test('UT-RC-09 お別れ・削除済み・他のおうちの猫を除き、登録順に返す', () async {
      await addCat(
        db,
        id: 'c0',
        householdId: 'h1',
        name: 'タマ',
        createdAt: testTime.subtract(const Duration(days: 1)),
      );
      await addCat(
        db,
        id: 'c2',
        householdId: 'h1',
        name: 'ソラ',
        status: 'farewell',
      );
      await addCat(
        db,
        id: 'c3',
        householdId: 'h1',
        name: 'クロ',
        deletedAt: testTime,
      );
      await addCat(db, id: 'c4', householdId: 'h2', name: 'シロ');

      final cats = await repo.watchActiveCats('h1').first;

      expect(cats.map((c) => c.name), ['タマ', 'ミケ']);
    });
  });

  group('addRecord', () {
    test('UT-RC-10 詳細なしで保存し、同期待ちの変更も残す', () async {
      await repo.addStandardTypes('h1');
      final food = await firstType('h1');

      final id = await repo.addRecord(
        catId: 'c1',
        recordTypeId: food.id,
        author: author,
      );

      final record = await (db.select(
        db.records,
      )..where((r) => r.id.equals(id))).getSingle();
      expect(record.authorName, 'はる');
      expect(record.memo, isNull);
      expect(record.recordedAt, now);
      final pending = await db.select(db.pendingChanges).getSingle();
      expect(pending.rowId, id);
      expect(pending.userId, 'u1');
      expect(pending.targetTable, 'records');
      expect(pending.operation, 'upsert');
      expect(jsonDecode(pending.payload), containsPair('catId', 'c1'));
    });

    test('UT-RC-11 同じ項目を同じ日に何回でも記録できる', () async {
      await repo.addStandardTypes('h1');
      final food = await firstType('h1');

      for (var i = 0; i < 3; i++) {
        await repo.addRecord(
          catId: 'c1',
          recordTypeId: food.id,
          author: author,
        );
      }

      expect(await repo.watchDay('h1', now).first, hasLength(3));
    });

    test('UT-RC-12 存在しない猫には保存せず、同期待ちも残さない', () async {
      await repo.addStandardTypes('h1');
      final food = await firstType('h1');

      await expectLater(
        repo.addRecord(catId: 'none', recordTypeId: food.id, author: author),
        throwsA(anything),
      );

      expect(await db.select(db.records).get(), isEmpty);
      expect(await db.select(db.pendingChanges).get(), isEmpty);
    });
  });

  group('watchDay', () {
    Future<void> recordAt(DateTime at, String typeId) async {
      now = at;
      await repo.addRecord(catId: 'c1', recordTypeId: typeId, author: author);
    }

    test('UT-RC-13 その日の 0:00 から 23:59 までを新しい順に返す', () async {
      await repo.addStandardTypes('h1');
      final food = await firstType('h1');
      await recordAt(DateTime(2026, 11, 1, 23, 59), food.id);
      await recordAt(DateTime(2026, 11, 2, 0, 0), food.id);
      await recordAt(DateTime(2026, 11, 2, 23, 59), food.id);
      await recordAt(DateTime(2026, 11, 3, 0, 0), food.id);

      final day = await repo.watchDay('h1', DateTime(2026, 11, 2, 12)).first;

      expect(day.map((e) => e.recordedAt), [
        DateTime(2026, 11, 2, 23, 59),
        DateTime(2026, 11, 2, 0, 0),
      ]);
      expect(day.first.catName, 'ミケ');
      expect(day.first.typeName, 'ご飯');
    });

    test('UT-RC-14 削除済みの記録と他のおうちの記録は含めない', () async {
      await repo.addStandardTypes('h1');
      await repo.addStandardTypes('h2');
      await addCat(db, id: 'c9', householdId: 'h2', name: 'シロ');
      final food = await firstType('h1');
      final other = await firstType('h2');
      final id = await repo.addRecord(
        catId: 'c1',
        recordTypeId: food.id,
        author: author,
      );
      await repo.addRecord(catId: 'c9', recordTypeId: other.id, author: author);
      await repo.addRecord(catId: 'c1', recordTypeId: food.id, author: author);
      await (db.update(db.records)..where((r) => r.id.equals(id))).write(
        RecordsCompanion(deletedAt: Value(testTime)),
      );

      expect(await repo.watchDay('h1', now).first, hasLength(1));
    });
  });
}
