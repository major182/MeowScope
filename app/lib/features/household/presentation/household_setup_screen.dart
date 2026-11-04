import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/readable_width.dart';

/// おうちの作成または参加（S-04）
///
/// 作った人はログイン中のユーザーで、投稿者名には新規登録の名前を使う（BR-17）。
/// おうちのない人もログアウトと退会ができるよう、画面の下に小さく入口を置く
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _householdName = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _householdName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = ref.read(authUserProvider).value;
    if (_saving || user == null || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    await ref
        .read(householdRepositoryProvider)
        .createHousehold(householdName: _householdName.text, user: user);
    // おうちができたら、続けて最初の猫を登録する（S-05）
    router.push('/cats/new');
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await ref.read(authRepositoryProvider).logout();
    // 最初の画面へ戻ると、ログアウト済みなのでログイン（S-01）が出る
    router.go('/');
  }

  /// おうちがないので、記録を残すかは聞かずに確認だけする（残す側で送る）
  Future<void> _delete() async {
    final user = ref.read(authUserProvider).value;
    if (_saving || user == null) {
      return;
    }
    final ok = await confirmDelete(
      context,
      title: 'アカウントを削除しますか？',
      message: 'ログインできなくなり、元に戻せません',
    );
    if (!ok || !mounted) {
      return;
    }
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteAccount(userId: user.id, keepRecords: true);
      router.go('/');
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message())));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.read で読めるよう、ログイン中のユーザーを見張っておく
    ref.watch(authUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('おうちを準備します')),
      body: Form(
        key: _form,
        child: ListView(
          padding: readablePadding(context, 16),
          children: [
            TextFormField(
              controller: _householdName,
              decoration: const InputDecoration(labelText: 'おうちの名前'),
              validator: _required('おうちの名前'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: const Text('新しいおうちを作る'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.push('/join'),
              child: const Text('招待されたおうちに参加'),
            ),
          ],
        ),
      ),
      // 新規登録した人も見る画面なので、目立たないよう下に小さく置く
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuietButton(label: 'ログアウト', onPressed: _saving ? null : _logout),
              const SizedBox(width: 16),
              _QuietButton(
                label: 'アカウントを削除',
                onPressed: _saving ? null : _delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 目立たない小さな文字のボタン
class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        textStyle: theme.textTheme.bodySmall,
      ),
      child: Text(label),
    );
  }
}

/// 空欄と空白だけの入力を受け付けない
FormFieldValidator<String> _required(String label) =>
    (value) => (value?.trim().isEmpty ?? true) ? '$labelを入力してください' : null;
