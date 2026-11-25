import 'package:flutter_test/flutter_test.dart';

import '../../tool/stay_on.dart';

/// E2E の後に戻す「画面を消さない」の設定（#316）
void main() {
  test('UT-E2E-01 数なら値として読む（改行は除く）。0 も読む', () {
    expect(parseStayOn(0, '0\r\n'), '0');
    expect(parseStayOn(0, '2\n'), '2');
    expect(parseStayOn(0, '15'), '15');
  });

  test('UT-E2E-02 異常系：失敗・数でない・空なら読まない（戻さない）', () {
    expect(parseStayOn(1, '2'), isNull);
    expect(parseStayOn(0, 'null'), isNull);
    expect(parseStayOn(0, ''), isNull);
    expect(parseStayOn(0, '-1'), isNull);
    expect(parseStayOn(0, 'd'), isNull);
  });
}
