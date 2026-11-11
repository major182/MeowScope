import 'package:flutter/services.dart';

/// メールアドレスとパスワードの入力の決まり（BR-26、API 設計書 2章）
///
/// サーバーでも同じ決まりで検証する。ここでは、送る前に利用者へ知らせるために使う
abstract final class Credentials {
  static const passwordMin = 8;
  static const passwordMax = 64;
  static const nameMax = 20;

  /// 半角の英数字と記号だけ（空白を含まない）
  static final _ascii = RegExp(r'^[\x21-\x7E]*$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isAscii(String value) => _ascii.hasMatch(value);

  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    return _email.hasMatch(text) ? null : 'メールアドレスの形で入力してください';
  }

  static String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.length < passwordMin || text.length > passwordMax) {
      return 'パスワードは$passwordMin〜$passwordMax文字で入力してください';
    }
    return null;
  }

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '名前を入力してください';
    }
    return text.length > nameMax ? '名前は$nameMax文字までです' : null;
  }
}

/// 全角などの文字を受け付けない入力の部品（BR-26）
///
/// 1文字ずつの入力も、貼り付けも、全角が混ざっていたら入力欄を変えずに [onRejected] を呼ぶ。
/// 一部だけ取り込むと、気付かないまま違う値になるので、まるごと受け付けない
///
/// IME で変換している途中（composing）は、そのまま表示する。途中で取り消すと、入力欄と IME の
/// 持つ文字がずれ、確定のときに文字が増える（#172）。確定したときに全角が混ざっていれば、
/// 変換を始める前の内容に戻す。変換の前の内容を覚えるので、入力欄ごとに1つ作って使い続ける
class AsciiOnlyFormatter extends TextInputFormatter {
  AsciiOnlyFormatter({required this.onRejected, this.onAccepted});

  final void Function() onRejected;

  /// 確定した半角の入力を受け付けたとき（変換の途中は呼ばない）
  final void Function()? onAccepted;

  /// 変換を始める前の、確定した内容
  TextEditingValue? _beforeComposing;

  static bool _composing(TextEditingValue value) =>
      value.composing.isValid && !value.composing.isCollapsed;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_composing(newValue)) {
      if (!_composing(oldValue)) {
        _beforeComposing = oldValue;
      }
      return newValue;
    }
    final before = _composing(oldValue)
        ? (_beforeComposing ?? TextEditingValue.empty)
        : oldValue;
    _beforeComposing = null;
    if (Credentials.isAscii(newValue.text)) {
      onAccepted?.call();
      return newValue;
    }
    onRejected();
    return before.copyWith(composing: TextRange.empty);
  }
}

/// 招待の文やリンク（`meowscope://invite?token=...`）から、トークンを取り出す。
/// トークンだけを貼り付けても受け付ける。見つからなければ null
String? extractInviteToken(String text) {
  final inLink = RegExp(r'token=([A-Za-z0-9_-]{20,100})').firstMatch(text);
  if (inLink != null) {
    return inLink.group(1);
  }
  final trimmed = text.trim();
  return RegExp(r'^[A-Za-z0-9_-]{20,100}$').hasMatch(trimmed) ? trimmed : null;
}
