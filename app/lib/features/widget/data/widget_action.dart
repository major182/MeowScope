import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/household_choice.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/data/record_repository.dart';
import 'widget_host.dart';

/// ウィジェットから記録する（F-WG-01、BR-23）。アプリの画面は開かずに、裏側で動く
///
/// 受け取るリンクは `meowscope://widget/record?type=<記録項目の ID>&cat=<猫の ID>&widget=<ウィジェットの ID>`。
/// 「✓ ミケのご飯を記録しました」は、押した時点で Android の側が先に出している（待ちを感じさせないため）。
/// ここでは保存して、そのウィジェットの記録待ちの印を消す。保存できなければ、失敗の文に書き換えて
/// [failedDuration] だけ出す（元のボタンに戻すのは Android の側。この処理は書いた後すぐに止められることがあるため）。
/// 記録の内容は同期待ちに積まれ、次の同期でサーバーへ送られる
///
/// おうちごとにウィジェットを置けるので（BR-40）、今のおうちではなく、押した項目と猫のおうちに記録する
/// 保存できなかったときの文（Android の側と同じ）
const widgetFailedMessage = '記録できませんでした。アプリを開いてください';

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
  final widgetId = int.tryParse(uri.queryParameters['widget'] ?? '');
  if (widgetId == null) {
    // どのウィジェットか分からなければ、印を消す先も結果を出す先もないので何もしない
    return;
  }
  final saved = await _record(
    db,
    typeId: uri.queryParameters['type'],
    catId: uri.queryParameters['cat'],
  );
  await host.remove(WidgetKeys.pending(widgetId));
  if (!saved) {
    await host.showUi(
      widgetId,
      'done',
      message: widgetFailedMessage,
      until: clock().add(failedDuration),
    );
  }
}

/// 記録を保存する。保存できたら真
Future<bool> _record(
  AppDatabase db, {
  required String? typeId,
  required String? catId,
}) async {
  final states = {
    for (final s in await db.select(db.appStates).get()) s.key: s.value,
  };
  final userId = states[SessionKeys.userId];
  final userName = states[SessionKeys.userName];
  if (userId == null || userName == null || typeId == null || catId == null) {
    return false;
  }
  final cat =
      await (db.select(db.cats)..where(
            (c) =>
                c.id.equals(catId) &
                c.deletedAt.isNull() &
                c.status.equals('active'),
          ))
          .getSingleOrNull();
  final type =
      await (db.select(db.recordTypes)..where(
            (t) =>
                t.id.equals(typeId) &
                t.deletedAt.isNull() &
                t.hidden.equals(false),
          ))
          .getSingleOrNull();
  if (cat == null || type == null) {
    return false;
  }
  // 猫と項目が同じおうちのもので、そのおうちに今も入っていること
  // （抜けたおうちや、ずれた古い表示から記録しないため）
  final mine = {for (final h in await myHouseholds(db, userId).get()) h.id};
  if (cat.householdId != type.householdId || !mine.contains(cat.householdId)) {
    return false;
  }
  await RecordRepository(db).addRecord(
    catId: cat.id,
    recordTypeId: type.id,
    author: Author(id: userId, name: userName),
  );
  return true;
}
