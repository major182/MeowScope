import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../sync/presentation/sync_status_screen.dart';
import '../../household/data/household_repository.dart';
import '../data/record_repository.dart';
import 'record_format.dart';
import 'record_providers.dart';
import 'type_icon.dart';

final _catsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

final _todayProvider = StreamProvider.autoDispose<List<RecordEntry>>((ref) {
  final session = ref.watch(sessionProvider).value;
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
    final session = ref.watch(sessionProvider).value;
    // おうちがないときは StartScreen がおうちの作成を出すので、ここでは待つだけ
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final types = ref.watch(recordTypesProvider).value ?? const [];
    final today = ref.watch(_todayProvider).value ?? const [];
    // ボタンを押す前に猫の一覧を読み込んでおく
    final cats = ref.watch(_catsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          const SyncIndicator(),
          TextButton.icon(
            onPressed: () => context.push('/cats/new'),
            icon: const Icon(Icons.add),
            label: const Text('猫を追加'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (cats.isEmpty)
            Card(
              child: ListTile(
                title: const Text('猫が登録されていません'),
                subtitle: const Text('記録の前に、猫を登録してください'),
                trailing: FilledButton(
                  onPressed: () => context.push('/cats/new'),
                  child: const Text('登録する'),
                ),
              ),
            ),
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
              leading: Text(formatTime(e.recordedAt)),
              title: Text('${e.catName}　${e.typeName}'),
              onTap: () => context.push('/records/${e.id}'),
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
    final router = GoRouter.of(context);
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
    final id = await ref
        .read(recordRepositoryProvider)
        .addRecord(
          catId: cat.id,
          recordTypeId: type.id,
          author: session.author,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text('${cat.name}の${type.name}を記録しました'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '詳細を追加',
          onPressed: () => router.push('/records/$id/edit'),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.onPressed});

  final RecordTypeRow type;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      // 既定の丸い形では名前が枠に重なるので、角丸の四角にする
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TypeIcon(icon: type.icon, name: type.name),
          ),
          // 「ブラッシング」が収まるよう、幅に合わせて文字を縮める
          FittedBox(fit: BoxFit.scaleDown, child: Text(type.name, maxLines: 1)),
        ],
      ),
    );
  }
}
