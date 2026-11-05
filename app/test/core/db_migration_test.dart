import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';

import '../helpers/test_db.dart';

/// 端末の DB の版の更新を確かめる。いまの表の定義で作った DB を、古い版の形に戻してから開き直す
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('meowscope_db_');
    file = File('${dir.path}/test.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open({void Function(dynamic raw)? setup}) => AppDatabase(
    DatabaseConnection(
      NativeDatabase(file, setup: setup),
      closeStreamsSynchronously: true,
    ),
  );

  /// 試しのデータ（仮の利用者・おうち・猫・記録・同期待ち）と端末の設定を入れて、版を [version] にする
  Future<void> prepare(int version) async {
    final db = open();
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await db
        .into(db.recordTypes)
        .insert(
          RecordTypesCompanion.insert(
            id: 't1',
            createdAt: testTime,
            updatedAt: testTime,
            householdId: 'h1',
            name: '通院',
            kind: 'custom',
          ),
        );
    await db
        .into(db.records)
        .insert(
          RecordsCompanion.insert(
            id: 'r1',
            createdAt: testTime,
            updatedAt: testTime,
            catId: 'c1',
            recordTypeId: 't1',
            recordedAt: testTime,
            authorName: 'はる',
            authorId: const Value('local-user'),
          ),
        );
    await db
        .into(db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            userId: 'local-user',
            targetTable: 'records',
            rowId: 'r1',
            operation: 'upsert',
            payload: '{}',
          ),
        );
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'local-user'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        AppStatesCompanion.insert(key: 'settings.weekStart', value: 'monday'),
      ]),
    );
    if (version < 10) {
      await db.customStatement('DROP TABLE rejected_changes');
      await db.customStatement(
        "INSERT INTO app_states (key, value) VALUES ('sync.rejected.local-user', '3')",
      );
    }
    if (version < 9) {
      await db.customStatement('DROP TABLE widget_buttons');
    }
    if (version < 8) {
      await db.customStatement('ALTER TABLE cats DROP COLUMN has_icon');
      for (final column in ['has_icon', 'icon_seq']) {
        await db.customStatement(
          'ALTER TABLE household_members DROP COLUMN $column',
        );
      }
    }
    if (version < 7) {
      await db.customStatement('DROP TABLE client_logs');
    }
    if (version < 5) {
      for (final table in ['record_photos', 'pending_photos', 'local_photos']) {
        await db.customStatement('DROP TABLE $table');
      }
    }
    if (version < 4) {
      await db.customStatement('DROP TABLE household_members');
    }
    if (version < 2) {
      await db.customStatement('ALTER TABLE record_types DROP COLUMN hidden');
    }
    await db.customStatement('PRAGMA user_version = $version');
    await db.close();
  }

  test('UT-HD-05 版 1 の DB を開くと非表示の列が足される', () async {
    await prepare(1);
    final db = open();
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(record_types)')
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns, contains('hidden'));
  });

  test('UT-AU-01 版 2 の DB を開くと、認証の前の試しのデータを消し、端末の設定は残す', () async {
    await prepare(2);
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.records).get(), isEmpty);
    expect(await db.select(db.recordTypes).get(), isEmpty);
    expect(await db.select(db.cats).get(), isEmpty);
    expect(await db.select(db.households).get(), isEmpty);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    final states = await db.select(db.appStates).get();
    expect(
      {for (final s in states) s.key: s.value},
      {'settings.weekStart': 'monday'},
    );
  });

  test('UT-AU-02 境界値：版 3 の DB を開き直してもデータは消えない', () async {
    await prepare(3);
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.records).get(), hasLength(1));
    expect(await db.select(db.appStates).get(), hasLength(4));
  });

  test('UT-WB-01 版 8 の DB を開くと、ウィジェットのボタンの表ができ、データは残る', () async {
    await prepare(8);
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.widgetButtons).get(), isEmpty);
    expect(await db.select(db.records).get(), hasLength(1));
  });

  test('UT-RJ-01 版 9 の DB を開くと、送れなかった変更の表ができ、件数だけの記録は捨てる。ほかのデータは残る', () async {
    await prepare(9);
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.rejectedChanges).get(), isEmpty);
    final keys = [for (final s in await db.select(db.appStates).get()) s.key];
    expect(keys, isNot(contains('sync.rejected.local-user')));
    expect(keys, contains('settings.weekStart'));
    expect(await db.select(db.records).get(), hasLength(1));
  });
}
