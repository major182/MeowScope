import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/providers.dart';
import '../auth/data/auth_repository.dart';
import 'data/widget_action.dart';
import 'data/widget_host.dart';
import 'data/widget_publisher.dart';

/// ウィジェットのボタンを押したときに、アプリの画面を開かずに裏側で呼ばれる
///
/// アプリとは別に動くので、DB と同期の部品を自分で用意して、終わったら閉じる
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) {
    return;
  }
  final container = ProviderContainer();
  try {
    final db = container.read(databaseProvider);
    final host = HomeWidgetHost();
    await handleWidgetAction(uri, db: db, host: host);
    // 家族の端末にも早く届くよう、つながれば送っておく。失敗しても、次にアプリを開いたときに送る
    try {
      final user = await (db.select(
        db.appStates,
      )..where((s) => s.key.equals(SessionKeys.userId))).getSingleOrNull();
      if (user != null) {
        await container.read(syncEngineProvider).run(user.value);
      }
    } on Object {
      // 何もしない
    }
  } finally {
    container.dispose();
  }
}

/// アプリの状態が変わるたびに、ウィジェットへ渡す（Android のみ）
void startWidgetBridge(ProviderContainer container) {
  // ウィジェットからの記録は別の場所で DB に書かれ、アプリの画面には知らされない。
  // アプリが前面に戻ったら、記録まわりの表を読み直させる
  AppLifecycleListener(
    onResume: () {
      final db = container.read(databaseProvider);
      db.notifyUpdates({
        TableUpdate.onTable(db.records),
        TableUpdate.onTable(db.pendingChanges),
      });
    },
  );
  unawaited(HomeWidget.registerInteractivityCallback(widgetBackgroundCallback));
  final publisher = WidgetPublisher(HomeWidgetHost());
  container.listen(
    widgetSnapshotProvider,
    (_, next) => unawaited(publisher.publish(next)),
    fireImmediately: true,
  );
}
