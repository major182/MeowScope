import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Matrix4, Rect, Size;
import 'package:image/image.dart' as img;

/// アイコンの切り抜き（F-SH-10）の計算。画面から分けて、単体テストで確かめる
///
/// 切り抜きの画面は、一辺 [viewport] の正方形の枠に画像を「隙間なく覆う」大きさ（BoxFit.cover）で置き、
/// それを InteractiveViewer で動かし・拡大する。枠に見えている正方形が、アイコンになる範囲

/// 画像を枠いっぱいに覆うときの、画面に置く大きさ（拡大する前）
Size coverSize(Size image, double viewport) {
  final scale =
      viewport / (image.width < image.height ? image.width : image.height);
  return Size(image.width * scale, image.height * scale);
}

/// 拡大する前に、画像の真ん中が枠の真ん中に来るよう、ずらす量
Matrix4 centeredTransform(Size image, double viewport) {
  final placed = coverSize(image, viewport);
  return Matrix4.translationValues(
    -(placed.width - viewport) / 2,
    -(placed.height - viewport) / 2,
    0,
  );
}

/// 枠に見えている正方形を、画像の画素の座標で返す
///
/// [transform] は InteractiveViewer の変換（拡大 s と、ずらす量 tx・ty）。
/// 置いた画像の座標では、見えている左上は (-tx/s, -ty/s)、一辺は viewport/s。
/// それを画像の画素に直すため、置いた大きさの倍率で割る。画像の外にはみ出さないよう、内側に収める
Rect visibleSquare({
  required Size image,
  required double viewport,
  required Matrix4 transform,
}) {
  final s = transform.getMaxScaleOnAxis();
  final t = transform.getTranslation();
  final toPixels = image.width / coverSize(image, viewport).width;
  var side = viewport / s * toPixels;
  final shortest = image.width < image.height ? image.width : image.height;
  if (side > shortest) {
    side = shortest;
  }
  final left = (-t.x / s * toPixels).clamp(0.0, image.width - side);
  final top = (-t.y / s * toPixels).clamp(0.0, image.height - side);
  return Rect.fromLTWH(left, top, side, side);
}

/// [jpeg] の [region]（画素の座標）を切り抜いて JPEG にする。読めなければ null
///
/// 送る前の縮小（512px）は今までどおり IconRepository.setIcon が行うので、ここでは画質を高めに保つ
Uint8List? cropJpeg(Uint8List jpeg, Rect region) {
  final image = img.decodeImage(jpeg);
  if (image == null) {
    return null;
  }
  final cropped = img.copyCrop(
    image,
    x: region.left.round(),
    y: region.top.round(),
    width: region.width.round(),
    height: region.height.round(),
  );
  return img.encodeJpg(cropped, quality: 95);
}
