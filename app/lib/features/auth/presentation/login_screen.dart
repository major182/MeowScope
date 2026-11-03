import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../domain/credentials.dart';
import 'credential_field.dart';

/// ログイン（S-01）
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_sending || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .login(email: _email.text, password: _password.text);
      // ログインできたら、最初の画面がホームかおうちの作成に切り替わる
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message({
            401: 'メールアドレスかパスワードが違います',
            429: 'ログインの失敗が続いたため、しばらく待ってからやり直してください',
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'MeowScope',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 32),
              CredentialField(
                controller: _email,
                label: 'メールアドレス',
                validator: Credentials.validateEmail,
              ),
              const SizedBox(height: 12),
              CredentialField(
                controller: _password,
                label: 'パスワード',
                password: true,
                // ログインでは長さを確かめない。誤りはサーバーが同じ文で返す
                validator: (v) => (v ?? '').isEmpty ? 'パスワードを入力してください' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _sending ? null : _login,
                child: const Text('ログイン'),
              ),
              const Divider(height: 48),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('新規アカウント作成'),
              ),
              TextButton(
                onPressed: () => context.push('/login-help'),
                child: const Text('ログインに困ったら'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ログインに困ったら（S-07）
///
/// パスワードの再設定はメール送信の手段が決まってから（Q-26）押せるようにする。問い合わせは S-06 を開く
class LoginHelpScreen extends StatelessWidget {
  const LoginHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログインに困ったら')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            enabled: false,
            title: Text('パスワード再発行'),
            subtitle: Text('準備中'),
          ),
          ListTile(
            title: const Text('問い合わせ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/contact'),
          ),
        ],
      ),
    );
  }
}
