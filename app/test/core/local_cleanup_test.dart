import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/db/local_cleanup.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    for (final (household, cat, schedule) in [
      ('h1', 'c1', 'm1'),
      ('h2', 'c2', 'm2'),
    ]) {
      await addHousehold(db, household);
      await addCat(db, id: cat, householdId: household, name: 'ミケ');
      await db
          .into(db.medicationSchedules)
          .insert(
            MedicationSchedulesCompanion.insert(
              id: schedule,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: household,
              catId: cat,
              name: '○○錠',
              timeOfDay: '08:00',
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<List<String>> schedules() async => [
    for (final m in await db.select(db.medicationSchedules).get()) m.id,
  ];

  test('UT-MD-02 おうちのデータを消すと、そのおうちのお薬の予定も消え、すべて消すと残らない', () async {
    await removeHouseholdLocally(db, 'u1', 'h1');
    expect(await schedules(), ['m2']);

    await wipeLocalData(db);
    expect(await schedules(), isEmpty);
  });
}
