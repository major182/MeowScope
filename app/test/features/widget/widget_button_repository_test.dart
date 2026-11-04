import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/db/local_cleanup.dart';
import 'package:meowscope/features/widget/data/widget_button_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late WidgetButtonRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = WidgetButtonRepository(db, clock: () => testTime);
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    for (final (id, household) in [
      ('t1', 'h1'),
      ('t2', 'h1'),
      ('t3', 'h1'),
      ('t4', 'h1'),
      ('t5', 'h1'),
      ('x1', 'h2'),
    ]) {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: household,
              name: id,
              kind: 'custom',
              hidden: Value(id == 't5'),
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<List<String>> shown([String household = 'h1']) async => [
    for (final b in await repo.watchButtons('u1', household).first) b.type.id,
  ];

  Future<List<PendingChangeRow>> pendings() =>
      db.select(db.pendingChanges).get();

  test('UT-WB-02 追加した順に並び、同期待ちに積む。自分の・今のおうちの項目のボタンだけを出す', () async {
    await repo.add(userId: 'u1', recordTypeId: 't2');
    await repo.add(userId: 'u1', recordTypeId: 't1');
    await repo.add(userId: 'u1', recordTypeId: 'x1');
    await repo.add(userId: 'u2', recordTypeId: 't3');

    expect(await shown(), ['t2', 't1']);
    expect(await shown('h2'), ['x1']);
    final p = await pendings();
    expect(p, hasLength(4));
    expect(p.map((e) => e.targetTable).toSet(), {'widget_buttons'});
  });

  test('UT-WB-03 境界値：4つまで追加でき、5つ目と同じ項目の2つ目は追加できない', () async {
    for (final t in ['t1', 't2', 't3']) {
      await repo.add(userId: 'u1', recordTypeId: t);
    }
    await expectLater(
      repo.add(userId: 'u1', recordTypeId: 't1'),
      throwsStateError,
    );
    await repo.add(userId: 'u1', recordTypeId: 't4');
    await expectLater(
      repo.add(userId: 'u1', recordTypeId: 't5'),
      throwsStateError,
    );
    expect(await shown(), ['t1', 't2', 't3', 't4']);
  });

  test('UT-WB-04 削除すると並び順を詰め、空いた分をまた追加できる。他の人のボタンは消せない', () async {
    final a = await repo.add(userId: 'u1', recordTypeId: 't1');
    await repo.add(userId: 'u1', recordTypeId: 't2');
    await repo.add(userId: 'u1', recordTypeId: 't3');
    await repo.add(userId: 'u1', recordTypeId: 't4');

    await repo.remove(userId: 'u1', id: a);
    await repo.add(userId: 'u1', recordTypeId: 't5');

    expect(await shown(), ['t2', 't3', 't4', 't5']);
    final orders = [
      for (final w in await (db.select(
        db.widgetButtons,
      )..where((w) => w.deletedAt.isNull())).get())
        w.sortOrder,
    ];
    expect(orders..sort(), [0, 1, 2, 3]);
    await expectLater(repo.remove(userId: 'u2', id: a), throwsStateError);
  });

  test('UT-WB-05 並べ替え：変わった行だけを同期待ちに積み、出ていない他のおうちのボタンは後ろに回す', () async {
    final x = await repo.add(userId: 'u1', recordTypeId: 'x1');
    final a = await repo.add(userId: 'u1', recordTypeId: 't1');
    final b = await repo.add(userId: 'u1', recordTypeId: 't2');
    final before = (await pendings()).length;

    await repo.reorder(userId: 'u1', orderedIds: [b, a]);

    expect(await shown(), ['t2', 't1']);
    final changed = (await pendings()).skip(before).map((p) => p.rowId);
    // 並びは x・a・b から b・a・x になる。a は1番目のままなので積まない
    expect(changed, unorderedEquals([b, x]));

    final again = (await pendings()).length;
    await repo.reorder(userId: 'u1', orderedIds: [b, a]);
    expect(await pendings(), hasLength(again));
  });

  test('UT-WB-06 非表示の項目のボタンは出し、削除された項目のボタンは出さない', () async {
    await repo.add(userId: 'u1', recordTypeId: 't5');
    await repo.add(userId: 'u1', recordTypeId: 't1');
    await (db.update(db.recordTypes)..where((t) => t.id.equals('t1'))).write(
      RecordTypesCompanion(deletedAt: Value(testTime)),
    );

    final buttons = await repo.watchButtons('u1', 'h1').first;
    expect(buttons.map((b) => (b.type.id, b.type.hidden)), [('t5', true)]);
  });

  test('UT-WB-07 おうちのデータを消すと、そのおうちの項目のボタンも消える', () async {
    await repo.add(userId: 'u1', recordTypeId: 't1');
    await repo.add(userId: 'u1', recordTypeId: 'x1');

    await removeHouseholdLocally(db, 'u1', 'h1');
    expect(
      [for (final w in await db.select(db.widgetButtons).get()) w.recordTypeId],
      ['x1'],
    );

    await wipeLocalData(db);
    expect(await db.select(db.widgetButtons).get(), isEmpty);
  });
}
