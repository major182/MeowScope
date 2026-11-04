import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/keep_records_dialog.dart';
import '../../auth/data/account_repository.dart';
import '../../icons/icon_avatar.dart';
import '../../icons/icon_repository.dart';
import '../../sync/presentation/sync_controller.dart';

final _householdNameProvider = StreamProvider.family<String?, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchHouseholdName(id),
);

final _membersProvider = StreamProvider.family<List<Member>, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchMembers(id),
);

/// おうちの管理（S-42）
///
/// 招待はメール送信の手段が決まるまで（Q-26）「準備中」とする
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final _name = TextEditingController();
  var _loaded = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName(String householdId, String userId) async {
    if (_name.text.trim().isEmpty) {
      return;
    }
    await ref
        .read(accountRepositoryProvider)
        .renameHousehold(
          householdId: householdId,
          userId: userId,
          name: _name.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('おうちの名前を保存しました')));
    }
  }

  /// 招待の文を作ってコピーし、LINE などに貼り付けて送ってもらう
  Future<void> _invite(String householdId, String householdName) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // 招待した人の手元の猫と記録を先に送っておき、参加した人にすぐ届くようにする
      await ref.read(syncControllerProvider.notifier).sync();
      final message = await ref
          .read(accountRepositoryProvider)
          .createInvitation(
            householdId: householdId,
            householdName: householdName,
          );
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('招待の文をコピーしました'),
            content: Text('LINE などに貼り付けて送ってください。1時間以内に、1回だけ使えます。\n\n$message'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _leave(String householdId, String userId, bool last) async {
    final bool? keep;
    if (last) {
      // 最後の1人のときは、おうちと記録がすべて消える（BR-19）
      keep =
          await confirmDelete(
            context,
            title: 'おうちと記録をすべて削除しますか？',
            message: 'あなたが最後のメンバーです。おうちを抜けると、猫と記録と写真がすべて消えます。元に戻せません',
          )
          ? true
          : null;
    } else {
      keep = await askKeepRecords(context);
    }
    if (keep == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountRepositoryProvider)
          .leaveHousehold(
            userId: userId,
            householdId: householdId,
            keepRecords: keep,
          );
      router.go('/');
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message())));
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final id = session.householdId;
    final name = ref.watch(_householdNameProvider(id)).value;
    if (!_loaded && name != null) {
      _name.text = name;
      _loaded = true;
    }
    final members = ref.watch(_membersProvider(id)).value ?? const <Member>[];
    // 同期でまだ届いていなければ、自分だけのおうちとして扱う
    final others = members.where((m) => m.userId != session.author.id);
    return Scaffold(
      appBar: AppBar(title: const Text('おうちの管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'おうち名',
              suffixIcon: TextButton(
                onPressed: () => _saveName(id, session.author.id),
                child: const Text('保存'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('メンバー', style: Theme.of(context).textTheme.titleSmall),
          ListTile(
            leading: IconAvatar(
              icon:
                  members
                      .where((m) => m.userId == session.author.id)
                      .firstOrNull
                      ?.icon ??
                  IconRef(IconOwner.user, session.author.id),
            ),
            title: Text(session.author.name),
          ),
          for (final m in others)
            ListTile(
              leading: IconAvatar(icon: m.icon),
              title: Text(m.name),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _invite(id, name ?? ''),
            icon: const Icon(Icons.link),
            label: const Text('リンクで招待する'),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.mail_outline),
            title: Text('メールで招待する'),
            subtitle: Text('準備中'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _leave(id, session.author.id, others.isEmpty),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('おうちを抜ける'),
          ),
        ],
      ),
    );
  }
}
