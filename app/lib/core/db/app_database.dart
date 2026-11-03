import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Households, Cats, RecordTypes, Records, AppStates, PendingChanges],
)
class AppDatabase extends _$AppDatabase {
  /// テストでは、メモリー上の DB などを渡す
  AppDatabase(super.executor);

  /// 端末のアプリ用フォルダーに置く DB を開く
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'meowscope'));

  @override
  // 1：最初の版　2：記録項目に hidden（非表示）を追加
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(recordTypes, recordTypes.hidden);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
