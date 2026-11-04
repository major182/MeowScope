import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../domain/credentials.dart';
import '../../../core/widgets/readable_width.dart';
import 'credential_field.dart';

/// 新規登録（S-02）
///
/// 名前は記録の投稿者名に使う（BR-17）。第1段階で S-04 にあった「あなたの名前」をここへ移した
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_sending || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
          );
      // 最初の画面へ戻ると、ログイン済みなのでおうちの作成（S-04）が出る
      router.go('/');
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message({409: 'このメールアドレスはすでに登録されています'});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規アカウント作成')),
      body: Form(
        key: _form,
        child: ListView(
          padding: readablePadding(context, 16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名前',
                helperText: '記録に投稿者として表示します',
              ),
              validator: Credentials.validateName,
            ),
            const SizedBox(height: 12),
            CredentialField(
              controller: _email,
              label: 'メールアドレス',
              validator: Credentials.validateEmail,
            ),
            const SizedBox(height: 12),
            CredentialField(
              controller: _password,
              label:
                  'パスワード（${Credentials.passwordMin}〜${Credentials.passwordMax}文字）',
              password: true,
              validator: Credentials.validatePassword,
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
              onPressed: _sending ? null : _register,
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
