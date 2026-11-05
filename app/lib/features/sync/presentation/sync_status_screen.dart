import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import 'sync_controller.dart';

/// 日時を「11/02 09:30」の形にする
String formatSyncTime(DateTime? time) {
  if (time == null) {
    return 'まだ同期していません';
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.month)}/${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}

/// 同期の状態（S-46）
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  Future<void> _relogin(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    // 未送信の変更はユーザーの ID と一緒に残るので、入り直した後に送られる（API 設計書 2章）
    await ref.read(authRepositoryProvider).logout();
    router.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final info = ref.watch(syncInfoProvider).value;
    final error = state.error;
    return Scaffold(
      appBar: AppBar(title: const Text('同期の状態')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          ListTile(
            title: const Text('最終同期'),
            trailing: Text(formatSyncTime(info?.lastSyncedAt)),
          ),
          ListTile(
            title: const Text('未送信'),
            trailing: Text('${info?.pending ?? 0}件'),
          ),
          if ((info?.rejected ?? 0) > 0)
            ListTile(
              title: const Text('送れなかった変更'),
              subtitle: const Text('内容に誤りがあり、サーバーが受け付けませんでした'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${info!.rejected}件'),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => context.push('/sync/rejected'),
            ),
          if (error != null)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('前回の同期に失敗しました'),
              subtitle: Text(error.message()),
            )
          else if (info?.lastRequestId != null)
            ListTile(
              title: const Text('問い合わせ番号'),
              subtitle: Text(info!.lastRequestId!),
            ),
          if (state.needsLogin) ...[
            const ListTile(
              leading: Icon(Icons.lock_clock),
              title: Text('ログインの期限が切れました'),
              subtitle: Text('記録は端末に残っています。ログインし直すと送信します'),
            ),
            OutlinedButton(
              onPressed: () => _relogin(context, ref),
              child: const Text('ログインし直す'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: state.running
                ? null
                : () => ref.read(syncControllerProvider.notifier).sync(),
            child: Text(state.running ? '同期しています…' : '今すぐ同期'),
          ),
        ],
      ),
    );
  }
}

/// ホームの上部に出す同期の印。押すと手動で同期する（画面設計書 1章）
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final info = ref.watch(syncInfoProvider).value;
    // 印の形と状態の文（S-10：同期済み・未送信あり・同期中・失敗）
    final (IconData icon, String status) = switch (state) {
      _ when state.running => (Icons.sync, '同期中'),
      _ when state.error != null || state.needsLogin => (Icons.cloud_off, '失敗'),
      _ when (info?.pending ?? 0) > 0 => (Icons.cloud_upload_outlined, '未送信あり'),
      _ => (Icons.cloud_done_outlined, '同期済み'),
    };
    final time = info?.lastSyncedAt == null
        ? '未同期'
        : formatSyncTime(info!.lastSyncedAt);
    return TextButton.icon(
      onPressed: state.running
          ? null
          : () => ref.read(syncControllerProvider.notifier).sync(),
      icon: Icon(icon, size: 18),
      // 横に最終同期の時刻を出す（画面設計書 5章 S-46 の決まり）
      label: Text(
        '$time  $status',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
