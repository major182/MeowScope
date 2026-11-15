import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'domain/icon_crop.dart';

/// 拡大できる最大の倍率
const iconCropMaxScale = 5.0;

/// 切り抜きの枠の一辺の上限（広い画面で大きくなりすぎないように）
const iconCropMaxViewport = 360.0;

/// アイコンの切り抜きの画面を開く（F-SH-10、画面設計書 S-41・S-45）
///
/// [image] は向きを直して縮めた JPEG（表示と切り抜きを同じ画像で行い、ずれを防ぐ）。
/// 「決定」で切り抜いた JPEG を、閉じたら null を返す。確認の小窓と同じく、今の画面の上に重ねて開く
Future<Uint8List?> showIconCropper(BuildContext context, Uint8List image) {
  return Navigator.of(context).push(
    MaterialPageRoute<Uint8List>(
      fullscreenDialog: true,
      builder: (context) => IconCropScreen(image: image),
    ),
  );
}

/// アイコンの切り抜き。正方形の枠に丸い印を重ね、画像を動かし・拡大して範囲を決める
class IconCropScreen extends StatefulWidget {
  const IconCropScreen({super.key, required this.image});

  final Uint8List image;

  @override
  State<IconCropScreen> createState() => _IconCropScreenState();
}

class _IconCropScreenState extends State<IconCropScreen> {
  final _transform = TransformationController();

  /// 画像の大きさ（画素）。読めなければ null
  late final Size? _imageSize = _readSize();

  /// 今の枠の一辺。変わったら（Windows の窓の大きさを変えたなど）真ん中に置き直す
  double? _viewport;

  Size? _readSize() {
    final decoded = img.decodeImage(widget.image);
    return decoded == null
        ? null
        : Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _decide() {
    final size = _imageSize;
    final viewport = _viewport;
    if (size == null || viewport == null) {
      return;
    }
    final region = visibleSquare(
      image: size,
      viewport: viewport,
      transform: _transform.value,
    );
    Navigator.of(context).pop(cropJpeg(widget.image, region));
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    final hint = defaultTargetPlatform == TargetPlatform.windows
        ? 'ドラッグで動かし、ホイールで大きさを変えます'
        : '指で動かし、2本の指で大きさを変えます';
    return Scaffold(
      appBar: AppBar(
        title: const Text('アイコンの範囲'),
        actions: [
          TextButton(
            onPressed: size == null ? null : _decide,
            child: const Text('決定'),
          ),
        ],
      ),
      body: size == null
          ? const Center(child: Text('この画像は読み込めませんでした'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final viewport = [
                  constraints.maxWidth - 32,
                  constraints.maxHeight - 96,
                  iconCropMaxViewport,
                ].reduce((a, b) => a < b ? a : b);
                if (viewport != _viewport) {
                  _viewport = viewport;
                  _transform.value = centeredTransform(size, viewport);
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: viewport,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                transformationController: _transform,
                                // 画像は枠より大きく置くので、枠に合わせて縮めない
                                constrained: false,
                                // 画像が枠の外に出て、隙間ができないようにする
                                boundaryMargin: EdgeInsets.zero,
                                minScale: 1,
                                maxScale: iconCropMaxScale,
                                child: SizedBox.fromSize(
                                  size: coverSize(size, viewport),
                                  child: Image.memory(
                                    widget.image,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              // 丸の外を暗くして、アイコンに見える形を示す（触っても画像を動かせるよう、指は通す）
                              const IgnorePointer(
                                child: SizedBox.expand(
                                  child: CustomPaint(painter: _CircleMask()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(hint),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 丸の外を半透明の黒で覆う
class _CircleMask extends CustomPainter {
  const _CircleMask();

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Offset.zero & size);
    canvas.drawPath(outside, Paint()..color = Colors.black54);
  }

  @override
  bool shouldRepaint(_CircleMask oldDelegate) => false;
}
