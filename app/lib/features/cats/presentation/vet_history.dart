import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../records/domain/vet_detail.dart';
import '../../records/presentation/record_providers.dart';

/// 猫のプロフィール（S-41）の「病院の履歴」（F-MD-01）
///
/// その猫の病院の記録を新しい順に、日付・病院の名前・メモの1行目で出す。押すと記録の詳細へ進む
class VetHistory extends ConsumerWidget {
  const VetHistory({super.key, required this.catId});

  final String catId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(catVetHistoryProvider(catId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('病院の履歴', style: Theme.of(context).textTheme.titleMedium),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('まだ記録はありません'),
          ),
        for (final e in records)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${e.recordedAt.year}/${e.recordedAt.month}/${e.recordedAt.day}',
            ),
            title: Text(VetDetail.parse(e.detail).hospital ?? e.typeName),
            subtitle: switch (e.memo?.split('\n').first) {
              final line? => Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              null => null,
            },
            onTap: () => context.push('/records/${e.id}'),
          ),
      ],
    );
  }
}
