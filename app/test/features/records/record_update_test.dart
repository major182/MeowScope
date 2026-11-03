import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late RecordRepository repo;
  late String recordId;
  const author = Author(id: 'u1', name: 'はる');

  setUp(() async {
    db = memoryDatabase();
    now = DateTime(2026, 11, 2, 9, 30);
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await repo.addStandardTypes('h1');
    final food = (await repo.watchTypes('h1').first).first;
    recordId = await repo.addRecord(
      catId: 'c1',
      recordTypeId: food.id,
      author: author,
    );
    await db.delete(db.pendingChanges).go();
    now = DateTime(2026, 11, 2, 10);
  });

  tearDown(() => db.close());

  Future<List<PendingChangeRow>> pending() =>
      db.select(db.pendingChanges).get();

  test('UT-RD-07 記録1件を猫と項目の名前つきで返す', () async {
    final view = await repo.watchRecord(recordId).first;

    expect(view!.catName, 'ミケ');
    expect(view.typeName, 'ご飯');
    expect(view.kind, 'food');
  });

  test('UT-RD-08 存在しない記録は null', () async {
    expect(await repo.watchRecord('none').first, isNull);
  });

  test('UT-RD-09 詳細を更新し、同期待ちに残す', () async {
    final at = DateTime(2026, 11, 2, 8, 10);
    await repo.updateRecord(
      id: recordId,
      recordedAt: at,
      level: 'much',
      valueNumber: null,
      memo: '  完食  ',
      author: author,
    );

    final r = (await repo.watchRecord(recordId).first)!.record;
    expect(r.recordedAt.isAtSameMomentAs(at), isTrue);
    expect(r.level, 'much');
    expect(r.memo, '完食');
    expect(r.updatedAt.isAtSameMomentAs(now), isTrue);
    final changes = await pending();
    expect(changes.single.operation, 'upsert');
    expect(jsonDecode(changes.single.payload)['memo'], '完食');
  });

  test('UT-RD-10 空白だけのメモと未選択の量は空として保存する', () async {
    await repo.updateRecord(
      id: recordId,
      recordedAt: now,
      level: 'little',
      valueNumber: null,
      memo: 'あり',
      author: author,
    );
    await repo.updateRecord(
      id: recordId,
      recordedAt: now,
      level: null,
      valueNumber: null,
      memo: '   ',
      author: author,
    );

    final r = (await repo.watchRecord(recordId).first)!.record;
    expect(r.level, isNull);
    expect(r.memo, isNull);
  });

  test('UT-RD-11 体重の数値を保存する', () async {
    await repo.updateRecord(
      id: recordId,
      recordedAt: now,
      level: null,
      valueNumber: 4.2,
      memo: null,
      author: author,
    );

    expect((await repo.watchRecord(recordId).first)!.record.valueNumber, 4.2);
  });

  test('UT-RD-12 異常系：存在しない記録は更新せず、同期待ちも残さない', () async {
    await expectLater(
      repo.updateRecord(
        id: 'none',
        recordedAt: now,
        level: null,
        valueNumber: null,
        memo: null,
        author: author,
      ),
      throwsStateError,
    );
    expect(await pending(), isEmpty);
  });

  test('UT-RD-13 削除すると削除の時刻を残し、一覧と詳細から消え、同期待ちに残す', () async {
    await repo.deleteRecord(id: recordId, author: author);

    final row = await db.select(db.records).getSingle();
    expect(row.deletedAt!.isAtSameMomentAs(now), isTrue);
    expect(await repo.watchRecord(recordId).first, isNull);
    expect(await repo.watchDay('h1', now).first, isEmpty);
    expect((await pending()).single.operation, 'delete');
  });

  test('UT-RD-14 異常系：削除済みの記録はもう一度削除できない', () async {
    await repo.deleteRecord(id: recordId, author: author);

    await expectLater(
      repo.deleteRecord(id: recordId, author: author),
      throwsStateError,
    );
    expect(await pending(), hasLength(1));
  });
}
