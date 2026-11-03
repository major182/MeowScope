import 'package:flutter/material.dart';

import '../domain/credentials.dart';

/// メールアドレスとパスワードの入力欄（BR-26：全角を受け付けない）
///
/// 全角が入ろうとしたら入力欄を変えず、欄の下に案内を出す
class CredentialField extends StatefulWidget {
  const CredentialField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.password = false,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final bool password;

  @override
  State<CredentialField> createState() => _CredentialFieldState();
}

class _CredentialFieldState extends State<CredentialField> {
  var _rejected = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.password,
      autocorrect: false,
      enableSuggestions: !widget.password,
      keyboardType: widget.password
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      inputFormatters: [
        AsciiOnlyFormatter(onRejected: () => setState(() => _rejected = true)),
      ],
      onChanged: (_) {
        if (_rejected) {
          setState(() => _rejected = false);
        }
      },
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: _rejected ? '全角の文字は使えません。半角で入力してください' : null,
      ),
      validator: widget.validator,
    );
  }
}
