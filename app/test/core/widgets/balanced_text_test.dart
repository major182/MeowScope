import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/widgets/balanced_text.dart';

import '../../helpers/balanced_text_finder.dart';

void main() {
  // テスト用のフォントは、どの文字も「文字の大きさ」の正方形になる。10px の文字を [width] の幅に置く
  Future<Size> sizeOf(
    WidgetTester tester,
    String text, {
    double width = 100,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topLeft,
              child: BalancedText(text, style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(BalancedText));
  }

  test('UT-BT-01 改行してよいのは、ひらがなや記号の後ろで、次がひらがなでないところと、空白の前後だけ', () {
    // 印の入った所を | で表す（| の所では改行しない）
    String marks(String s) => phraseBreaks(s).replaceAll('\u2060', '|');

    expect(marks('招待の文をコピーしました'), '招|待|の文|をコ|ピ|ー|し|ま|し|た');
    expect(marks('アカウントを削除しますか？'), 'ア|カ|ウ|ン|ト|を削|除|し|ま|す|か？');
    // 読点の後ろはひらがなでも改行してよい。空白の前後も改行してよい
    expect(marks('文を、そのまま'), '文|を、そ|の|ま|ま');
    expect(marks('LINE など'), 'L|I|N|E な|ど');
    expect(marks(''), '');
  });

  testWidgets('UT-BT-02 1行に収まるときは幅を変えない（境界値：ちょうど幅いっぱい）', (tester) async {
    expect(await sizeOf(tester, '招待の文を'), const Size(50, 10));
    expect(await sizeOf(tester, '招待の文をコピーした'), const Size(100, 10));
  });

  testWidgets('UT-BT-03 折り返すときは言葉の切れ目で切り、行の長さをそろえる（「招待の文を／コピーしました」）', (
    tester,
  ) async {
    // 幅いっぱいに詰めると「招待の文をコピーしまし／た」になるところ
    final size = await sizeOf(tester, '招待の文をコピーしました', width: 110);
    expect(size.height, 20);
    expect(size.width, closeTo(70, 0.5));
  });

  testWidgets('UT-BT-04 3行になるときも行の数は増やさない', (tester) async {
    final size = await sizeOf(tester, '漢字を' * 7, width: 90);
    expect(size.height, 30);
    expect(size.width, closeTo(90, 0.5));
  });

  testWidgets('UT-BT-05 ダイアログの見出しに使っても表示でき、元の文で探せる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => AlertDialog(
            title: BalancedText('おうちの記録を残しますか？'),
            content: const Text('説明'),
          ),
        ),
      ),
    );
    expect(findBalancedText('おうちの記録を残しますか？'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
