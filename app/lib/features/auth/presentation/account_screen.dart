import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/keep_records_dialog.dart';
import '../domain/credentials.dart';
import 'credential_field.dart';

/// アカウント設定（S-45）。名前とパスワードの変更、ログアウト、退会。アイコンは No.14 で足す
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  var _loaded = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// 通信の要る操作を行い、失敗したら理由を出す
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on ApiError catch (e) {
      _show(e.message({403: '今のパスワードが違います'}));
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveName() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (await _run(
      () => ref.read(accountRepositoryProvider).rename(_name.text),
    )) {
      _show('名前を保存しました');
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (result == null) {
      return;
    }
    final (current, next) = result;
    if (await _run(
      () => ref
          .read(accountRepositoryProvider)
          .changePassword(current: current, next: next),
    )) {
      _show('パスワードを変更しました');
    }
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await ref.read(authRepositoryProvider).logout();
    // 最初の画面へ戻ると、ログアウト済みなのでログイン（S-01）が出る
    router.go('/');
  }

  Future<void> _delete(String userId) async {
    final keep = await askKeepRecords(context);
    if (keep == null || !mounted) {
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
    if (await _run(
      () => ref
          .read(accountRepositoryProvider)
          .deleteAccount(userId: userId, keepRecords: keep),
    )) {
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).value;
    if (!_loaded && user != null) {
      _name.text = user.name;
      _loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: '名前',
                helperText: 'これからの記録の投稿者名になります',
                suffixIcon: TextButton(
                  onPressed: _busy ? null : _saveName,
                  child: const Text('保存'),
                ),
              ),
              validator: Credentials.validateName,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _busy ? null : _changePassword,
              child: const Text('パスワードを変更'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _logout,
              child: const Text('ログアウト'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy || user == null ? null : () => _delete(user.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('アカウントを削除'),
            ),
          ],
        ),
      ),
    );
  }
}

/// パスワードの変更の入力。今のパスワードと新しいパスワードを返す
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('パスワードを変更'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CredentialField(
              controller: _current,
              label: '今のパスワード',
              password: true,
              validator: (v) => (v ?? '').isEmpty ? '今のパスワードを入力してください' : null,
            ),
            CredentialField(
              controller: _next,
              label:
                  '新しいパスワード（${Credentials.passwordMin}〜${Credentials.passwordMax}文字）',
              password: true,
              validator: Credentials.validatePassword,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (_current.text, _next.text));
            }
          },
          child: const Text('変更する'),
        ),
      ],
    );
  }
}
