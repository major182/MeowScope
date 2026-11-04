import 'package:flutter/material.dart';

import 'balanced_text.dart';

/// 退会とおうちを抜けるときの確認（画面設計書 5章）。記録を残すか消すかを選ぶ（BR-16）
///
/// 残すなら true、消すなら false、キャンセルなら null を返す
Future<bool?> askKeepRecords(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: BalancedText('おうちの記録を残しますか？'),
    content: const Text('残すと、あなたの名前のまま記録が残ります。消すと、あなたが投稿した記録だけを消します'),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('残す'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('消す'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
    ],
  ),
);
