import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/record_repository.dart';
import '../domain/record_kind.dart';

final _typesProvider = StreamProvider.autoDispose<List<RecordTypeRow>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchTypes(session.householdId);
});

final _catsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

final _todayProvider = StreamProvider.autoDispose<List<RecordEntry>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchDay(session.householdId, DateTime.now());
});

/// ホーム（S-10）。項目 → 猫 → 即保存の流れで記録する
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('おうちがまだありません')));
    }
    final types = ref.watch(_typesProvider).value ?? const [];
    final today = ref.watch(_todayProvider).value ?? const [];
    // ボタンを押す前に猫の一覧を読み込んでおく
    final cats = ref.watch(_catsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final t in types)
                _TypeButton(
                  type: t,
                  onPressed: () => _record(context, ref, session, cats, t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('今日の記録', style: Theme.of(context).textTheme.titleMedium),
          if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('まだ記録がありません'),
            ),
          for (final e in today)
            ListTile(
              leading: Text(_hm(e.recordedAt)),
              title: Text('${e.catName}　${e.typeName}'),
            ),
        ],
      ),
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<CatRow> cats,
    RecordTypeRow type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (cats.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('先に猫を登録してください')));
      return;
    }
    // 猫が1匹なら選択を省く
    final cat = cats.length == 1
        ? cats.single
        : await showDialog<CatRow>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text('${type.name}：どの子ですか？'),
              children: [
                for (final c in cats)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, c),
                    child: Text(c.name),
                  ),
              ],
            ),
          );
    if (cat == null) {
      return;
    }
    await ref
        .read(recordRepositoryProvider)
        .addRecord(
          catId: cat.id,
          recordTypeId: type.id,
          author: session.author,
        );
    messenger.showSnackBar(
      SnackBar(content: Text('${cat.name}の${type.name}を記録しました')),
    );
  }
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.onPressed});

  final RecordTypeRow type;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final asset = iconAsset(type.icon);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(4)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: asset == null
                ? const Icon(Icons.star_outline)
                : Image.asset(asset, semanticLabel: type.name),
          ),
          Text(type.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
