import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 今の時刻を返す関数。テストで差し替える
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 今日の日付（0時0分）。アプリを開いたまま日付が変わったら、新しい日付を流す
///
/// ホームの「今日の記録」とカレンダーの「今日」が、前の日のまま残らないようにする
final todayProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => dayStream(ref.watch(nowProvider)),
);

/// 今日の日付を流し、次の0時を過ぎたら次の日付を流す
///
/// 端末が眠っていた間に0時を過ぎたときは、起きてタイマーが動いたときに流す。
/// 聞く人がいなくなったらタイマーを止める
Stream<DateTime> dayStream(DateTime Function() now) {
  Timer? timer;
  late final StreamController<DateTime> controller;
  void emit() {
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    controller.add(today);
    // 0時ちょうどに起きると、時計の誤差で前の日のままになることがあるので、少し後にする
    final next = DateTime(today.year, today.month, today.day + 1);
    timer = Timer(next.difference(current) + const Duration(seconds: 1), emit);
  }

  controller = StreamController<DateTime>(
    onListen: emit,
    onCancel: () => timer?.cancel(),
  );
  return controller.stream;
}
