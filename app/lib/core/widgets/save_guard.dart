import 'package:flutter/material.dart';

import '../logging/app_log.dart';

/// 端末への保存に失敗したときの文（画面設計書 5章）
const saveFailedMessage = '保存できませんでした。もう一度お試しください';

/// 端末の DB への保存などを行う。失敗したら案内を出し、端末のログに残して false を返す
///
/// [log] と [messenger] は、待つ前に取っておいたものを渡す（待っている間に画面が閉じても使えるように）。
/// ログには例外の種類だけを書く（内容に記録が含まれるおそれがあるため。ログ設計書 6章）
Future<bool> guardSave({
  required AppLog log,
  required ScaffoldMessengerState messenger,
  required String what,
  required Future<void> Function() action,
}) async {
  try {
    await action();
    return true;
  } on Object catch (e) {
    await log.record('error', '$whatに失敗：${e.runtimeType}');
    messenger.showSnackBar(const SnackBar(content: Text(saveFailedMessage)));
    return false;
  }
}
