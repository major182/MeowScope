import 'package:flutter/material.dart';

/// 削除の確認。誤操作を防ぐため、左に削除、右にキャンセルを置く（BR-29）。
/// 削除を選んだときだけ true を返す
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('削除'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
      ],
    ),
  );
  return result ?? false;
}
