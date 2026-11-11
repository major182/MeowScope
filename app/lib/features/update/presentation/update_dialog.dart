import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/update_installer.dart';
import '../domain/app_release.dart';
import '../update_providers.dart';

/// 取ってこられなかったときの文（画面設計書 S-51）
const updateFailedMessage = '更新を取ってこられませんでした。もう一度試してください';

/// 更新のお知らせ（S-51）を出す。「5分後に知らせる」なら5分後にもう一度出す
Future<void> showUpdateDialog(BuildContext context, UpdateAvailable update) {
  return showDialog<void>(
    context: context,
    // 外を押して閉じると、どちらを選んだか分からなくなるので閉じさせない
    barrierDismissible: false,
    builder: (_) => UpdateDialog(update: update),
  );
}

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.update});

  final UpdateAvailable update;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  /// 取ってきている間は 0.0〜1.0、まだなら null
  double? _progress;

  void _later() {
    ref.read(updatePromptProvider.notifier).remindLater(widget.update);
    Navigator.of(context).pop();
  }

  Future<void> _updateNow() async {
    setState(() => _progress = 0);
    // 待った後に画面が閉じていても使えるよう、先に取っておく（CLAUDE.md 3章）
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final log = ref.read(appLogProvider);
    try {
      await ref
          .read(updateInstallerProvider)
          .install(
            widget.update.release,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      // Android はインストールの画面から戻ったところ（取りやめた）。Windows はここに来る前にアプリが閉じる
      if (mounted) navigator.pop();
    } on UpdateFailed catch (e) {
      unawaited(log.record('warning', '更新に失敗：${e.reason}'));
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(updateFailedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final release = widget.update.release;
    return PopScope(
      // 取ってきている間は閉じさせない。それ以外で戻るのは「5分後に知らせる」と同じにする
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && progress == null) _later();
      },
      child: AlertDialog(
        title: const Text('新しい版があります'),
        content: progress == null
            ? Text(
                'Ver.${release.version} に更新できます\n'
                '（今の版 Ver.${widget.update.installed.version}）\n'
                '更新すると、アプリを一度閉じて開き直します',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('更新を取ってきています（${(progress * 100).floor()}%）'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                ],
              ),
        actions: progress == null
            ? [
                TextButton(onPressed: _later, child: const Text('5分後に知らせる')),
                FilledButton(onPressed: _updateNow, child: const Text('今すぐ更新')),
              ]
            : null,
      ),
    );
  }
}
