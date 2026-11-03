import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Households,
    HouseholdMembers,
    Cats,
    RecordTypes,
    Records,
    RecordPhotos,
    AppStates,
    PendingChanges,
    PendingPhotos,
    LocalPhotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// テストでは、メモリー上の DB などを渡す
  AppDatabase(super.executor);

  /// 端末のアプリ用フォルダーに置く DB を開く
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'meowscope'));

  @override
  // 1：最初の版　2：記録項目に hidden（非表示）を追加　3：認証の前に作ったデータを消す
  // 4：おうちのメンバーの表を追加（同期）　5：写真の表を追加
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(recordTypes, recordTypes.hidden);
      }
      if (from < 3) {
        // 認証の前に端末だけで作ったデータは試しのデータとして扱い、アカウントへ引き継がない
        // （画面設計書 S-04）。週の始まりなどの端末の設定は残す
        await batch((b) {
          b.deleteAll(records);
          b.deleteAll(recordTypes);
          b.deleteAll(cats);
          b.deleteAll(households);
          b.deleteAll(pendingChanges);
          b.deleteWhere(appStates, (s) => s.key.like('session.%'));
        });
      }
      if (from < 4) {
        await m.createTable(householdMembers);
      }
      if (from < 5) {
        await m.createTable(recordPhotos);
        await m.createTable(pendingPhotos);
        await m.createTable(localPhotos);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
