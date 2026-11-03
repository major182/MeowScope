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
class AsciiOnlyFormatter extends TextInputFormatter {
  AsciiOnlyFormatter({required this.onRejected});

  final void Function() onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (Credentials.isAscii(newValue.text)) {
      return newValue;
    }
    onRejected();
    return oldValue;
  }
}
