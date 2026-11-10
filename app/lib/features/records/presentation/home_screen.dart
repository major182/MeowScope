import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../notifications/data/permission_prompt.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../icons/icon_avatar.dart';
import '../../icons/icon_repository.dart';
import '../../../core/today.dart';
import '../../../app/main_shell.dart' show wideLayoutWidth;
import '../../sync/presentation/sync_status_screen.dart';
import '../../household/data/household_repository.dart';
import '../data/record_repository.dart';
import '../../../core/widgets/balanced_text.dart';
import '../../../core/widgets/save_guard.dart';
import 'record_format.dart';
import 'record_providers.dart';
import 'today_detail.dart';
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

/// 上部に出すおうち名（S-10）
final _householdNameProvider = StreamProvider.autoDispose<String?>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(null);
  }
  return ref
      .watch(accountRepositoryProvider)
      .watchHouseholdName(session.householdId);
});

final _todayProvider = StreamProvider.autoDispose<List<RecordEntry>>((ref) {
  final session = ref.watch(sessionProvider).value;
  // 日付が変わったら、新しい日の記録を見張り直す（B-3）
  final today = ref.watch(todayProvider).value;
  if (session == null || today == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchDay(session.householdId, today);
});

/// 広い画面での記録のボタン1つの幅の上限
const typeButtonMaxWidth = 160.0;

/// 記録のボタンの並べ方。狭い画面は4列、広い画面は幅に上限を設けて、窓が広いほど列を増やす
SliverGridDelegate _typeGrid(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutWidth
    ? const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: typeButtonMaxWidth,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      )
    : const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      );

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
    final detail = TodayDetail.forPlatform;
    return Scaffold(
      // 左上におうち名、右に同期の状態（S-10）。猫の追加は設定の猫の一覧（S-41）から行う
      appBar: AppBar(
        title: Text(ref.watch(_householdNameProvider).value ?? ''),
        actions: const [SyncIndicator()],
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
          GridView(
            gridDelegate: _typeGrid(context),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
              title: Align(
                alignment: Alignment.centerLeft,
                child: IconLabel(
                  icon: e.catIcon,
                  text: '${e.catName}　${e.typeName}',
                ),
              ),
              subtitle: switch (todayDetailText(e, detail)) {
                null => null,
                // Android は一覧が長くならないよう2行までにする。Windows は全文を出す
                final text => Text(
                  text,
                  maxLines: detail == TodayDetail.all ? null : 2,
                  overflow: detail == TodayDetail.all
                      ? null
                      : TextOverflow.ellipsis,
                ),
              },
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
    // 猫を選ぶのを待つ間に画面が閉じても使えるよう、先に取っておく
    final repo = ref.read(recordRepositoryProvider);
    final log = ref.read(appLogProvider);
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
              title: BalancedText('${type.name}：どの子ですか？'),
              children: [
                for (final c in cats)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, c),
                    child: IconLabel(
                      icon: IconRef(
                        IconOwner.cat,
                        c.id,
                        hasIcon: c.hasIcon,
                        version: c.serverSeq,
                      ),
                      text: c.name,
                      radius: 16,
                    ),
                  ),
                // 外側を押しても閉じるが、閉じ方が分かるようにボタンも置く（S-11）
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                  ),
                ),
              ],
            ),
          );
    if (cat == null) {
      return;
    }
    late final String id;
    final saved = await guardSave(
      log: log,
      messenger: messenger,
      what: '記録の追加',
      action: () async => id = await repo.addRecord(
        catId: cat.id,
        recordTypeId: type.id,
        author: session.author,
      ),
    );
    if (!saved) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('${cat.name}の${type.name}を記録しました'),
        duration: const Duration(seconds: 4),
        // ボタン付きの SnackBar は既定では自動で消えないので、4秒で消えるようにする
        persist: false,
        action: SnackBarAction(
          label: '詳細を追加',
          onPressed: () => router.push('/records/$id/edit'),
        ),
      ),
    );
    // 記録忘れ・いつもとの差の通知が初めて要るときに、許可を求める
    await askNotificationPermission(ref, {
      NotificationKind.reminder,
      NotificationKind.anomaly,
    });
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
          // 長い名前（独自の項目など）も収まるよう、幅に合わせて文字を縮める
          FittedBox(fit: BoxFit.scaleDown, child: Text(type.name, maxLines: 1)),
        ],
      ),
    );
  }
}
