import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/medication/data/medication_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late MedicationRepository repo;
  var now = DateTime.utc(2026, 11, 7, 1);

  setUp(() async {
    db = memoryDatabase();
    repo = MedicationRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'タマ',
      createdAt: testTime.add(const Duration(days: 1)),
    );
    await addCat(db, id: 'cx', householdId: 'h2', name: 'クロ');
  });
  tearDown(() => db.close());

  Future<List<String>> pendingIds() async => [
    for (final p in await db.select(db.pendingChanges).get())
      if (p.targetTable == 'medication_schedules') p.rowId,
  ];

  Future<String> add(
    String catId, {
    String name = '○○錠',
    String? dose,
    String time = '08:00',
    String household = 'h1',
  }) => repo.add(
    householdId: household,
    userId: 'u1',
    catId: catId,
    name: name,
    dose: dose,
    timeOfDay: time,
  );

  test('UT-MD-07 追加：前後の空白を除き、空の量は空にして同期待ちに入れる。オンで作る', () async {
    final id = await add('c1', name: '  ○○錠 ', dose: '  ');
    final row = await (db.select(
      db.medicationSchedules,
    )..where((m) => m.id.equals(id))).getSingle();
    expect(row.name, '○○錠');
    expect(row.dose, isNull);
    expect(row.enabled, isTrue);
    expect(row.householdId, 'h1');
    expect(row.createdAt.isAtSameMomentAs(now), isTrue);
    expect(await pendingIds(), [id]);
  });

  test('UT-MD-08 一覧：猫の登録順・時刻の順。削除した予定・削除した猫・ほかのおうちの予定は出さない。お別れの猫は出す', () async {
    final evening = await add('c1', time: '20:00');
    final morning = await add('c1', time: '08:00');
    final tama = await add('c2', time: '07:00');
    final gone = await add('c1', time: '09:00');
    await add('cx', household: 'h2');
    await repo.delete(id: gone, userId: 'u1');
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(status: Value('farewell')),
    );

    final list = await repo.watchSchedules('h1').first;
    expect([for (final e in list) e.schedule.id], [morning, evening, tama]);
    expect(list.last.cat.status, 'farewell');

    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      CatsCompanion(deletedAt: Value(testTime)),
    );
    expect(
      [for (final e in await repo.watchSchedules('h1').first) e.schedule.id],
      [morning, evening],
    );
  });

  test('UT-MD-09 変更・オン・オフ・削除：更新日時を進めて同期待ちに入れる。削除した予定は見張りで null', () async {
    final id = await add('c1', dose: '1錠');
    now = now.add(const Duration(hours: 1));
    await repo.update(
      id: id,
      userId: 'u1',
      catId: 'c2',
      name: '目薬',
      dose: '',
      timeOfDay: '21:30',
      enabled: true,
    );
    var row = await repo.watchSchedule(id).first;
    expect(row!.catId, 'c2');
    expect(row.name, '目薬');
    expect(row.dose, isNull);
    expect(row.timeOfDay, '21:30');
    expect(row.updatedAt.isAtSameMomentAs(now), isTrue);

    await repo.setEnabled(id: id, userId: 'u1', enabled: false);
    row = await repo.watchSchedule(id).first;
    expect(row!.enabled, isFalse);

    await repo.delete(id: id, userId: 'u1');
    expect(await repo.watchSchedule(id).first, isNull);
    expect(await pendingIds(), [id, id, id, id]);
  });

  test('UT-MD-10 異常系：削除した予定・ない予定は変えられない', () async {
    final id = await add('c1');
    await repo.delete(id: id, userId: 'u1');
    expect(
      () => repo.setEnabled(id: id, userId: 'u1', enabled: false),
      throwsStateError,
    );
    expect(() => repo.delete(id: 'none', userId: 'u1'), throwsStateError);
  });
}
