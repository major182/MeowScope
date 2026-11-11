import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// DB を置くフォルダーを返す関数。null なら drift の既定（アプリの文書のフォルダー）
///
/// Windows の既定は「ドキュメント」で、開発版と配布版が同じファイルを使ってしまう。
/// そのため Windows では、アプリ名（開発版は meowscope-dev）で分かれる保存先に置く（デプロイ設計書 6.3）。
/// Android はアプリの ID で分かれるので、既定のままにする
Future<Object> Function()? databaseDirectoryFor({required bool isWindows}) =>
    isWindows ? getApplicationSupportDirectory : null;

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
    ClientLogs,
    WidgetButtons,
    RejectedChanges,
    MedicationSchedules,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// テストでは、メモリー上の DB などを渡す
  AppDatabase(super.executor);

  /// 端末のアプリ用フォルダーに置く DB を開く
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'meowscope',
      native: DriftNativeOptions(
        databaseDirectory: databaseDirectoryFor(isWindows: Platform.isWindows),
      ),
    ),
  );

  @override
  // 1：最初の版　2：記録項目に hidden（非表示）を追加　3：認証の前に作ったデータを消す
  // 4：おうちのメンバーの表を追加（同期）　5：写真の表を追加
  // 6：メンバーのユーザーの ID を空にできるようにする（退会した人）
  // 7：端末のログの表を追加
  // 8：アイコンの有無を追加　9：ウィジェットのボタンの表を追加
  // 10：送れなかった変更の表を追加（件数だけの記録は、どの行か分からないので捨てる）
  // 11：猫にいつもとの差のしきい値を追加　12：お薬の予定の表を追加
  int get schemaVersion => 12;

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
      if (from >= 4 && from < 6) {
        // SQLite は列の制約を変えられないので、表を作り直して中身を移す
        await m.alterTable(TableMigration(householdMembers));
      }
      if (from < 7) {
        await m.createTable(clientLogs);
      }
      if (from < 8) {
        await m.addColumn(cats, cats.hasIcon);
        // 版 6 より前からの更新では、メンバーの表は上で新しい形で作り直されている
        if (from >= 6) {
          await m.addColumn(householdMembers, householdMembers.hasIcon);
          await m.addColumn(householdMembers, householdMembers.iconSeq);
        }
      }
      if (from < 9) {
        await m.createTable(widgetButtons);
      }
      if (from < 10) {
        await m.createTable(rejectedChanges);
        await (delete(
          appStates,
        )..where((s) => s.key.like('sync.rejected.%'))).go();
      }
      if (from < 11) {
        await m.addColumn(cats, cats.anomalyThresholds);
      }
      if (from < 12) {
        await m.createTable(medicationSchedules);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
