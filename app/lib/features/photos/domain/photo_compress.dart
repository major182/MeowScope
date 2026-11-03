import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 送る前に写真を縮める（BR-14、データ要件：長辺 1600px 程度、1枚 500KB を目安）
///
/// - スマートフォンの写真は向きの情報（EXIF）を持つので、先に向きを画素に反映してから縮める
/// - 長辺が [maxSide] より長いときだけ縮め、小さい写真は大きくしない
/// - JPEG で保存し直す。撮影場所などの情報（EXIF）は付けないので、外へ出ない
///
/// 画像として読めなければ null を返す
Uint8List? compressPhoto(
  Uint8List input, {
  int maxSide = 1600,
  int quality = 80,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    return null;
  }
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  image.exif.clear();
  return img.encodeJpg(image, quality: quality);
}
