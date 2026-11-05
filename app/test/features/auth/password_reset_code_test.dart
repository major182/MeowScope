import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/auth/presentation/password_reset_screen.dart';

void main() {
  test('UT-PR-11 確認コードの形：空・5桁・7桁・数字以外は誤り、6桁の数字は可（境界値）。前後の空白は除く', () {
    expect(validateResetCode(null), '確認コードを入力してください');
    expect(validateResetCode('  '), '確認コードを入力してください');
    expect(validateResetCode('12345'), '確認コードは6桁の数字です');
    expect(validateResetCode('1234567'), '確認コードは6桁の数字です');
    expect(validateResetCode('12345a'), '確認コードは6桁の数字です');
    expect(validateResetCode('012345'), isNull);
    expect(validateResetCode(' 012345 '), isNull);
  });

  test('UT-PR-13 送った後の案内：残りの秒数を入れる。0 秒なら秒数を出さない（境界値 1・0）', () {
    expect(
      sentNotice(1),
      '登録済みのメールアドレスに確認コードを送りました。届かない場合は、メールアドレスをお確かめの上、1秒後に再度実施して下さい。',
    );
    expect(
      sentNotice(0),
      '登録済みのメールアドレスに確認コードを送りました。届かない場合は、メールアドレスをお確かめの上、再度実施して下さい。',
    );
    expect(resendWaitSeconds, 60);
  });
}
