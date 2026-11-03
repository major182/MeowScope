import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late RecordRepository repo;
  late String foodId;
  const author = Author(id: 'u1', name: 'はる');

  setUp(() async {
    db = memoryDatabase();
    now = DateTime(2026, 11, 2, 9, 30);
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await repo.addStandardTypes('h1');
    foodId = (await repo.watchTypes('h1').first).first.id;
  });

  tearDown(() => db.close());

  Future<String> record(String catId, DateTime at) {
    now = at;
    return repo.addRecord(catId: catId, recordTypeId: foodId, author: author);
  }

  Stream<List<RecordEntry>> range({String? catId}) => repo.watchRange(
    'h1',
    from: DateTime(2026, 11, 2),
    to: DateTime(2026, 11, 3),
    catId: catId,
  );

  group('watchRange', () {
    test('UT-CL-11 境界値：from ちょうどは含め、to ちょうどは含めない。古い順', () async {
      await record('c1', DateTime(2026, 11, 1, 23, 59));
      await record('c1', DateTime(2026, 11, 2, 12));
      await record('c1', DateTime(2026, 11, 2));
      await record('c1', DateTime(2026, 11, 3));

      final list = await range().first;
      expect(list.map((e) => e.recordedAt), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 2, 12),
      ]);
    });

    test('UT-CL-12 猫で絞り込む。絞り込まなければ全員', () async {
      await record('c1', DateTime(2026, 11, 2, 8));
      await record('c2', DateTime(2026, 11, 2, 9));

      expect((await range().first).map((e) => e.catName), ['ミケ', 'タマ']);
      expect((await range(catId: 'c2').first).map((e) => e.catName), ['タマ']);
    });

    test('UT-CL-13 種類とメモの有無を返す', () async {
      final id = await record('c1', DateTime(2026, 11, 2, 8));
      await repo.updateRecord(
        id: id,
        recordedAt: DateTime(2026, 11, 2, 8),
        level: null,
        valueNumber: null,
        memo: '完食',
        author: author,
      );

      final e = (await range().first).single;
      expect(e.kind, 'food');
      expect(e.hasMemo, isTrue);
      expect(e.catId, 'c1');
    });

    test('UT-CL-14 削除した猫の記録は含めない', () async {
      await record('c1', DateTime(2026, 11, 2, 8));
      await (db.update(db.cats)..where((c) => c.id.equals('c1'))).write(
        CatsCompanion(deletedAt: Value(now)),
      );

      expect(await range().first, isEmpty);
    });
  });

  test('UT-CL-15 絞り込みの猫：お別れを含め、削除済みと他のおうちを除く', () async {
    await addCat(
      db,
      id: 'c3',
      householdId: 'h1',
      name: 'ソラ',
      status: 'farewell',
    );
    await addCat(db, id: 'c4', householdId: 'h1', name: 'クロ', deletedAt: now);
    await addCat(db, id: 'c5', householdId: 'h2', name: 'シロ');

    final cats = await repo.watchCats('h1').first;
    expect(cats.map((c) => c.name), ['ミケ', 'タマ', 'ソラ']);
  });

  test('UT-CL-16 週の始まり：未設定は日曜、保存すると切り替わる', () async {
    final settings = SettingsRepository(db);
    expect(await settings.watchWeekStart().first, WeekStart.sunday);

    await settings.setWeekStart(WeekStart.monday);
    expect(await settings.watchWeekStart().first, WeekStart.monday);

    await settings.setWeekStart(WeekStart.sunday);
    expect(await settings.watchWeekStart().first, WeekStart.sunday);
  });
}
