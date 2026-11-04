import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 入力欄やボタンが中心の画面で、中身を広げてよい幅の上限
const readableMaxWidth = 640.0;

/// 画面が広いときは左右の余白を増やし、中身の幅を [readableMaxWidth] までにする
///
/// 余白で狭めるので、スクロールできる範囲は画面の幅いっぱいのまま（マウスのホイールがどこでも効く）。
/// 画面が狭いときは、上下左右とも [padding] の余白になる
EdgeInsets readablePadding(BuildContext context, double padding) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(padding, (width - readableMaxWidth) / 2);
  return EdgeInsets.fromLTRB(side, padding, side, padding);
}
