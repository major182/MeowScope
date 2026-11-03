import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

/// アカウント設定（S-45）
///
/// いまは名前の表示とログアウトだけ。名前の変更・パスワードの変更・退会はアカウントの実装（No.12）、
/// アイコンは No.14 で足す
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(authRepositoryProvider).logout();
    // 最初の画面へ戻ると、ログアウト済みなのでログイン（S-01）が出る
    router.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('名前'),
            subtitle: Text(user?.name ?? ''),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _logout(context, ref),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
