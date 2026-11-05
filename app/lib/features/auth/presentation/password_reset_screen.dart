import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../domain/credentials.dart';
import 'credential_field.dart';

/// 確認コードを送り直せるまでの秒数（サーバーの送り直しの間隔と同じ）
const resendWaitSeconds = 60;

/// 確認コードを送った後の案内。送り直せるまでの秒数 [wait] を数え下げて出す
String sentNotice(int wait) => wait > 0
    ? '登録済みのメールアドレスに確認コードを送りました。届かない場合は、メールアドレスをお確かめの上、$wait秒後に再度実施して下さい。'
    : '登録済みのメールアドレスに確認コードを送りました。届かない場合は、メールアドレスをお確かめの上、再度実施して下さい。';

/// 確認コードの形（6桁の数字）を確かめる
String? validateResetCode(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return '確認コードを入力してください';
  }
  if (!RegExp(r'^[0-9]{6}$').hasMatch(text)) {
    return '確認コードは6桁の数字です';
  }
  return null;
}

/// パスワード再設定（S-03、F-AU-03）
///
/// 1. メールアドレスを入れて、6桁の確認コードをメールで送ってもらう
/// 2. 届いたコードと新しいパスワードを入れて変える。変えたらそのままログインし、ほかの端末はログインし直しになる
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  var _sent = false;
  var _sending = false;
  String? _error;

  /// 送り直せるまでの残りの秒数。0 なら送り直せる
  var _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_sending || !_emailForm.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
        _startWait();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message();
        });
      }
    }
  }

  /// 送り直せるまで、毎秒数え下げる（サーバーは1分以内の送り直しではメールを送らない）
  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = resendWaitSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _wait--);
      if (_wait <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _reset() async {
    if (_sending || !_resetForm.currentState!.validate()) {
      return;
    }
    final router = GoRouter.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: _email.text,
            code: _code.text,
            newPassword: _password.text,
          );
      // ログインした状態になったので、最初の画面（ホームかおうちの作成）へ戻る
      router.go('/');
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.code == 'INVALID_RESET_CODE'
              ? '確認コードが違うか、期限が切れています。5回間違えたときや15分過ぎたときは、コードを送り直してください'
              : e.message();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード再設定')),
      body: ListView(
        padding: readablePadding(context, 24),
        children: [
          Form(
            key: _emailForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('登録したメールアドレスに、6桁の確認コードを送ります'),
                const SizedBox(height: 12),
                CredentialField(
                  controller: _email,
                  label: 'メールアドレス',
                  validator: Credentials.validateEmail,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _sending || _wait > 0 ? null : _requestCode,
                  child: Text(_sent ? '確認コードを送り直す' : '確認コードを送る'),
                ),
              ],
            ),
          ),
          if (_sent) ...[const SizedBox(height: 12), Text(sentNotice(_wait))],
          if (_sent) ...[
            const Divider(height: 40),
            Form(
              key: _resetForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('メールに届いた確認コード（15分有効）と、新しいパスワードを入れてください'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: '確認コード（6桁）'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: validateResetCode,
                  ),
                  const SizedBox(height: 12),
                  CredentialField(
                    controller: _password,
                    label: '新しいパスワード（8〜64文字）',
                    password: true,
                    validator: Credentials.validatePassword,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _sending ? null : _reset,
                    child: const Text('パスワードを変更'),
                  ),
                ],
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
