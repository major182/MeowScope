import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/data/record_repository.dart';
import 'widget_host.dart';

/// ウィジェットから記録する（F-WG-01、BR-23）。アプリの画面は開かずに、裏側で動く
///
/// 受け取るリンクは `meowscope://widget/record?type=<記録項目の ID>&cat=<猫の ID>`。
/// 記録したら「✓ ミケのご飯を記録しました」を [doneDuration] だけ出す。元のボタンに戻すのは Android の側
/// （この処理は書いた後すぐに止められることがあり、待ってから戻すことができないため）。
/// 記録できなければ、その旨を出す。記録の内容は同期待ちに積まれ、次の同期でサーバーへ送られる
Future<void> handleWidgetAction(
  Uri uri, {
  required AppDatabase db,
  required WidgetHost host,
  DateTime Function() clock = DateTime.now,
}) async {
  if (uri.scheme != 'meowscope' ||
      uri.host != 'widget' ||
      uri.path != '/record') {
    return;
  }
  final message = await _record(
    db,
    typeId: uri.queryParameters['type'],
    catId: uri.queryParameters['cat'],
  );
  await host.showUi('done', message: message, until: clock().add(doneDuration));
}

/// 記録して、出す文を返す
Future<String> _record(
  AppDatabase db, {
  required String? typeId,
  required String? catId,
}) async {
  const failed = '記録できませんでした。アプリを開いてください';
  final states = {
    for (final s in await db.select(db.appStates).get()) s.key: s.value,
  };
  final userId = states[SessionKeys.userId];
  final userName = states[SessionKeys.userName];
  final householdId = states[SessionKeys.householdId];
  if (userId == null ||
      userName == null ||
      householdId == null ||
      typeId == null ||
      catId == null) {
    return failed;
  }
  // 押した時点の、今のおうちの猫と項目であること（別のおうちに切り替えた後の古い表示など）
  final cat =
      await (db.select(db.cats)..where(
            (c) =>
                c.id.equals(catId) &
                c.householdId.equals(householdId) &
                c.deletedAt.isNull() &
                c.status.equals('active'),
          ))
          .getSingleOrNull();
  final type =
      await (db.select(db.recordTypes)..where(
            (t) =>
                t.id.equals(typeId) &
                t.householdId.equals(householdId) &
                t.deletedAt.isNull() &
                t.hidden.equals(false),
          ))
          .getSingleOrNull();
  if (cat == null || type == null) {
    return failed;
  }
  await RecordRepository(db).addRecord(
    catId: cat.id,
    recordTypeId: type.id,
    author: Author(id: userId, name: userName),
  );
  return '✓ ${cat.name}の${type.name}を記録しました';
}
