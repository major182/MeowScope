// Windows のアイコン（app_icon.ico）を mainicon_01 から作る（画面設計書 1章）
// タスクバー・エクスプローラーが使う小さいサイズも入れる（256px だけだと、タスクバーに古いアイコンが残る）
// 使い方（app で）：dart run tool/launcher_icons/windows_ico.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const _sizes = [16, 20, 24, 32, 40, 48, 64, 256];

void main() {
  final source = img.decodePng(
    File('assets/icons/mainicon_01.png').readAsBytesSync(),
  )!;
  final images = [
    for (final size in _sizes)
      img.copyResize(
        source,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      ),
  ];
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(img.IcoEncoder().encodeImages(images));
  stdout.writeln('app_icon.ico：${_sizes.join('・')}px');
}
