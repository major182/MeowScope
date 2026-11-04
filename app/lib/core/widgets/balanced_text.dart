import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 改行させない印（WORD JOINER）。画面には出ない
const _noBreak = '\u2060';

bool _isHiragana(int c) => c >= 0x3041 && c <= 0x309F;

/// 読点・句点・コロン・感嘆符・疑問符など、その後ろで改行してよい記号
bool _isPunctuation(int c) => '、。，．：！？」』）'.codeUnits.contains(c);

bool _isSpace(int c) => c == 0x20 || c == 0x3000;

/// 日本語の文で、改行してよいのを「ひらがな（助詞など）や記号の後ろ」だけにする
///
/// 日本語はどの文字の間でも改行できるので、そのままでは「コ／ピー」のように言葉の途中で切れる。
/// 改行させたくない文字の間に、画面に出ない印を入れる。
/// 「招待の文を／コピーしました」「アカウントを／削除しますか？」のように切れるようになる
String phraseBreaks(String text) {
  final units = text.runes.toList();
  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (i > 0) {
      final prev = units[i - 1];
      final canBreak =
          _isSpace(prev) ||
          _isSpace(c) ||
          _isPunctuation(prev) ||
          (_isHiragana(prev) && !_isHiragana(c));
      if (!canBreak) {
        out.write(_noBreak);
      }
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

/// 折り返すときに、行の長さをそろえる文字（CSS の `text-wrap: balance` と同じ考え方）
///
/// 日本語はどの文字の間でも折り返すので、幅いっぱいに詰めると最後の行が1文字だけになることがある。
/// 改行は言葉の切れ目（[phraseBreaks]）だけにし、行の数が変わらない範囲で幅を狭めて、
/// 各行の長さを近づける。1行に収まるときは何もしない
class BalancedText extends SingleChildRenderObjectWidget {
  BalancedText(this.data, {super.key, TextStyle? style, TextAlign? textAlign})
    : super(
        child: Text(
          phraseBreaks(data),
          style: style,
          textAlign: textAlign,
          // 読み上げには元の文を使う
          semanticsLabel: data,
        ),
      );

  /// 元の文（改行させない印を入れる前）
  final String data;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBalanced();
}

class _RenderBalanced extends RenderProxyBox {
  /// 幅を狭める試しの回数。1回ごとに幅の候補が半分になるので、12回で十分に細かい
  static const _steps = 12;

  /// [measure] で子の大きさを測りながら、行の数が変わらない一番狭い幅を探す
  static Size _balance(
    BoxConstraints constraints,
    Size Function(BoxConstraints) measure,
  ) {
    final full = measure(constraints);
    if (!constraints.hasBoundedWidth) {
      return full;
    }
    final oneLine = measure(
      constraints.copyWith(minWidth: 0, maxWidth: double.infinity),
    );
    if (oneLine.height >= full.height) {
      return full;
    }
    var narrow = 0.0;
    var wide = full.width;
    for (var i = 0; i < _steps; i++) {
      final mid = (narrow + wide) / 2;
      final size = measure(constraints.copyWith(minWidth: 0, maxWidth: mid));
      // 行が増えると高さが増えるので、高さが同じなら行の数は変わっていない
      if (size.height > full.height) {
        narrow = mid;
      } else {
        wide = mid;
      }
    }
    return measure(constraints.copyWith(minWidth: 0, maxWidth: wide));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final balanced = _balance(constraints, (c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    size = constraints.constrain(balanced);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    return constraints.constrain(_balance(constraints, child.getDryLayout));
  }
}
