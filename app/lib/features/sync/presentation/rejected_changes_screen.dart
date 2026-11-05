import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../data/rejected_change_repository.dart';
import '../domain/rejected_guidance.dart';
import 'sync_controller.dart';
import 'sync_status_screen.dart' show formatSyncTime;

final rejectedChangeRepositoryProvider = Provider<RejectedChangeRepository>(
  (ref) => RejectedChangeRepository(ref.watch(databaseProvider)),
);

/// ログイン中の人の、送れなかった変更
final rejectedChangesProvider =
    StreamProvider.autoDispose<List<RejectedChangeView>>((ref) {
      final user = ref.watch(authUserProvider).value;
      if (user == null) {
        return Stream.value(const []);
      }
      return ref.watch(rejectedChangeRepositoryProvider).watch(user.id);
    });

/// 送れなかった変更（S-48）。どの変更が、なぜ送れなかったか、どうすればよいかを出す（Issue #83）
class RejectedChangesScreen extends ConsumerWidget {
  const RejectedChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changes = ref.watch(rejectedChangesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('送れなかった変更')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          if (changes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('送れなかった変更はありません'),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('次の変更は端末に残っていますが、サーバーに送れていません。家族の端末には届いていません'),
            ),
          for (final c in changes) _RejectedCard(change: c),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/contact'),
            child: const Text('解決しないときは問い合わせる'),
          ),
        ],
      ),
    );
  }
}

/// 一覧から消す前の確認。消すと、この変更は送らない（取り消せない）
Future<bool> _confirmDismiss(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一覧から消しますか？'),
        content: const Text('この変更はサーバーに送りません。端末の内容はそのまま残ります'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('消す'),
          ),
        ],
      ),
    ) ??
    false;

class _RejectedCard extends ConsumerWidget {
  const _RejectedCard({required this.change});

  final RejectedChangeView change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = guidanceFor(change.reason, change.field);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authUserProvider).value;
    final repo = ref.read(rejectedChangeRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(change.label, style: text.titleMedium),
            Text(
              '送れなかった日時：${formatSyncTime(change.rejectedAt.toLocal())}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('原因', style: text.labelLarge),
            Text(guide.cause),
            const SizedBox(height: 4),
            Text('対応', style: text.labelLarge),
            Text(guide.action),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (change.recordId != null)
                  TextButton(
                    onPressed: () =>
                        context.push('/records/${change.recordId}'),
                    child: const Text('記録を開く'),
                  ),
                TextButton(
                  onPressed: user == null
                      ? null
                      : () async {
                          if (await _confirmDismiss(context)) {
                            await repo.dismiss(user.id, change);
                          }
                        },
                  child: const Text('一覧から消す'),
                ),
                if (guide.canResend)
                  FilledButton(
                    onPressed: user == null
                        ? null
                        : () async {
                            await repo.resend(user.id, change);
                            await ref
                                .read(syncControllerProvider.notifier)
                                .sync();
                          },
                    child: const Text('送り直す'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
