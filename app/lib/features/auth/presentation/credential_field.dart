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

  /// 変換の前の内容を覚えるので、作り直さずに使い続ける（#172）
  late final _formatter = AsciiOnlyFormatter(
    onRejected: () => setState(() => _rejected = true),
    // 案内は、半角の入力を受け付けたときだけ消す。全角を取り消して入力欄を戻したときにも
    // onChanged は呼ばれるので、そこで消すと案内が出ない（#172）
    onAccepted: () {
      if (_rejected) {
        setState(() => _rejected = false);
      }
    },
  );

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
      inputFormatters: [_formatter],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: _rejected ? '全角の文字は使えません。半角で入力してください' : null,
      ),
      validator: widget.validator,
    );
  }
}
