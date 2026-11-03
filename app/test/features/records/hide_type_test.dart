import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/custom_type.dart';

import '../../helpers/test_db.dart';

void main() {
  group('非表示（リポジトリ）', () {
    late AppDatabase db;
    late RecordRepository repo;
    late String customId;

    setUp(() async {
      db = memoryDatabase();
      repo = RecordRepository(db, clock: () => DateTime(2026, 11, 3, 12));
      await addHousehold(db, 'h1');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await repo.addStandardTypes('h1');
      customId = await repo.addCustomType(
        householdId: 'h1',
        userId: 'u1',
        name: '通院',
        icon: CustomIcon.vet.value,
      );
      await db.delete(db.pendingChanges).go();
    });

    tearDown(() => db.close());

    test('UT-HD-01 非表示にすると記録の項目から外れ、すべての項目には残る。同期待ちに残す', () async {
      await repo.setTypeHidden(id: customId, userId: 'u1', hidden: true);

      expect(await repo.watchTypes('h1').first, hasLength(8));
      final all = await repo.watchTypes('h1', includeHidden: true).first;
      expect(all, hasLength(9));
      expect(all.last.hidden, isTrue);
      final change = (await db.select(db.pendingChanges).get()).single;
      expect(change.targetTable, 'record_types');
      expect(jsonDecode(change.payload)['hidden'], isTrue);
    });

    test('UT-HD-02 非表示にしても過去の記録はそのまま出る', () async {
      await repo.addRecord(
        catId: 'c1',
        recordTypeId: customId,
        author: const Author(id: 'u1', name: 'はる'),
      );

      await repo.setTypeHidden(id: customId, userId: 'u1', hidden: true);

      final day = await repo.watchDay('h1', DateTime(2026, 11, 3)).first;
      expect(day.single.typeName, '通院');
    });

    test('UT-HD-03 表示に戻すと記録の項目に戻る', () async {
      await repo.setTypeHidden(id: customId, userId: 'u1', hidden: true);
      await repo.setTypeHidden(id: customId, userId: 'u1', hidden: false);

      expect((await repo.watchTypes('h1').first).last.name, '通院');
    });

    test('UT-HD-04 異常系：標準の項目と存在しない項目は非表示にできず、同期待ちも残さない', () async {
      final food = (await repo.watchTypes('h1').first).first;

      for (final id in [food.id, 'none']) {
        await expectLater(
          repo.setTypeHidden(id: id, userId: 'u1', hidden: true),
          throwsStateError,
        );
      }
      expect(await repo.watchTypes('h1').first, hasLength(9));
      expect(await db.select(db.pendingChanges).get(), isEmpty);
    });
  });

  test('UT-HD-05 版 1 の DB を開くと非表示の列が足され、既存の項目は表示のまま', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (raw) {
            // 版 1 の記録項目の表（hidden の列がない）
            raw.execute('''
              CREATE TABLE record_types (
                id TEXT NOT NULL PRIMARY KEY,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER NULL,
                server_seq INTEGER NULL,
                household_id TEXT NOT NULL,
                name TEXT NOT NULL,
                icon TEXT NULL,
                kind TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0
              )
            ''');
            raw.execute(
              "INSERT INTO record_types (id, created_at, updated_at, household_id, name, kind) VALUES ('t1', 0, 0, 'h1', '通院', 'custom')",
            );
            raw.execute('PRAGMA user_version = 1');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final type = await db.select(db.recordTypes).getSingle();
    expect(type.name, '通院');
    expect(type.hidden, isFalse);
  });
}
