import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Households, Cats, RecordTypes, Records, PendingChanges])
class AppDatabase extends _$AppDatabase {
  /// テストでは、メモリー上の DB などを渡す
  AppDatabase(super.executor);

  /// 端末のアプリ用フォルダーに置く DB を開く
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'meowscope'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
