import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../data/record_repository.dart';
import '../domain/record_detail.dart';
import 'record_edit_screen.dart';
import 'record_format.dart';
import 'record_providers.dart';

/// 記録の詳細と編集（S-22）
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recordDetailProvider(recordId))
        .when(
          data: (view) =>
              view == null ? const RecordNotFound() : _Detail(view: view),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => const RecordNotFound(),
        );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.view});

  final RecordDetailView view;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDelete(
      context,
      title: 'この記録を削除しますか？',
      message:
          '${view.catName}の${view.typeName}（${formatDateTime(view.record.recordedAt.toLocal())}）',
    );
    final session = ref.read(sessionProvider).value;
    if (!ok || session == null) {
      return;
    }
    await ref
        .read(recordRepositoryProvider)
        .deleteRecord(id: view.record.id, author: session.author);
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = view.record;
    // 削除のときにセッションを使うので、読み込んでおく
    ref.watch(sessionProvider);
    final level = RecordLevel.parse(r.level);
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録の詳細'),
        actions: [
          TextButton(
            onPressed: () => context.push('/records/${r.id}/edit'),
            child: const Text('編集'),
          ),
          TextButton(
            onPressed: () => _delete(context, ref),
            child: const Text('削除'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${view.catName}　${view.typeName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${formatDateTime(r.recordedAt.toLocal())}　投稿者：${r.authorName}'),
          const Divider(height: 32),
          if (level != null) _Row(label: '量', value: level.label),
          if (r.valueNumber != null)
            _Row(label: '体重', value: formatWeight(r.valueNumber!)),
          if (r.memo != null) _Row(label: 'メモ', value: r.memo!),
          if (level == null && r.valueNumber == null && r.memo == null)
            const Text('詳細はまだありません'),
          PhotoGallery(recordId: r.id),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
