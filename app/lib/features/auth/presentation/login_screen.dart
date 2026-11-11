import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../domain/credentials.dart';
import '../../../core/widgets/readable_width.dart';
import '../../update/presentation/version_label.dart';
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
            padding: readablePadding(context, 24),
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
              // 今の版（F-UP-03）
              const VersionLabel(),
            ],
          ),
        ),
      ),
    );
  }
}

/// ログインに困ったら（S-07）
///
/// パスワード再発行は S-03 を開く。問い合わせは S-06 を開く
class LoginHelpScreen extends StatelessWidget {
  const LoginHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログインに困ったら')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          ListTile(
            title: const Text('パスワード再発行'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/login-help/password-reset'),
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
