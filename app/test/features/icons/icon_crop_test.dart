import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meowscope/features/icons/domain/icon_crop.dart';
import 'package:meowscope/features/icons/icon_crop_screen.dart';

/// 左から赤・緑・青の縦じまの JPEG。切り抜いた場所を色で確かめる
Uint8List stripes(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var x = 0; x < w; x++) {
    final color = x < w / 4
        ? img.ColorRgb8(255, 0, 0)
        : x < w * 3 / 4
        ? img.ColorRgb8(0, 255, 0)
        : img.ColorRgb8(0, 0, 255);
    for (var y = 0; y < h; y++) {
      image.setPixel(x, y, color);
    }
  }
  return img.encodeJpg(image, quality: 100);
}

/// 画像の真ん中の色（赤・緑・青のどれが一番強いか）
String centerColor(Uint8List jpeg) {
  final image = img.decodeImage(jpeg)!;
  final p = image.getPixel(image.width ~/ 2, image.height ~/ 2);
  if (p.r > p.g && p.r > p.b) return '赤';
  if (p.g > p.r && p.g > p.b) return '緑';
  return '青';
}

void main() {
  group('計算', () {
    test('UT-CR-01 枠を覆う大きさ：横長・縦長・正方形（同値分割）', () {
      expect(coverSize(const Size(2000, 1000), 300), const Size(600, 300));
      expect(coverSize(const Size(1000, 2000), 300), const Size(300, 600));
      expect(coverSize(const Size(500, 500), 300), const Size(300, 300));
    });

    test('UT-CR-02 動かさなければ、真ん中の正方形（横長は左右、縦長は上下を落とす）', () {
      for (final (image, expected) in [
        (const Size(2000, 1000), const Rect.fromLTWH(500, 0, 1000, 1000)),
        (const Size(1000, 2000), const Rect.fromLTWH(0, 500, 1000, 1000)),
        (const Size(500, 500), const Rect.fromLTWH(0, 0, 500, 500)),
      ]) {
        final region = visibleSquare(
          image: image,
          viewport: 300,
          transform: centeredTransform(image, 300),
        );
        expect(region, expected, reason: '$image');
      }
    });

    test('UT-CR-03 2倍に拡大すると、一辺が半分の範囲になる', () {
      // 2000×1000 を一辺 300 の枠に置くと 600×300（画素への倍率 10/3）
      final transform = Matrix4.identity()
        ..translateByDouble(-300, -150, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      final region = visibleSquare(
        image: const Size(2000, 1000),
        viewport: 300,
        transform: transform,
      );
      expect(region.width, closeTo(500, 0.001));
      expect(region.height, closeTo(500, 0.001));
      expect(region.left, closeTo(500, 0.001));
      expect(region.top, closeTo(250, 0.001));
    });

    test('UT-CR-04 境界：画像の外にはみ出す位置や、縮めすぎは画像の内側に収める', () {
      const image = Size(2000, 1000);
      // 左上より外（正のずらし）→ 左上の端
      var region = visibleSquare(
        image: image,
        viewport: 300,
        transform: Matrix4.translationValues(50, 50, 0),
      );
      expect(region, const Rect.fromLTWH(0, 0, 1000, 1000));
      // 右下より外 → 右下の端
      region = visibleSquare(
        image: image,
        viewport: 300,
        transform: Matrix4.translationValues(-5000, -5000, 0),
      );
      expect(region, const Rect.fromLTWH(1000, 0, 1000, 1000));
      // 1倍より小さい → 短い辺いっぱい
      region = visibleSquare(
        image: image,
        viewport: 300,
        transform: Matrix4.identity()..scaleByDouble(0.5, 0.5, 1, 1),
      );
      expect(region.width, 1000);
    });

    test('UT-CR-05 切り抜き：範囲の大きさと場所の色。読めない画像は null', () {
      final source = stripes(400, 200);
      final right = cropJpeg(source, const Rect.fromLTWH(320, 50, 80, 80))!;
      final decoded = img.decodeImage(right)!;
      expect((decoded.width, decoded.height), (80, 80));
      expect(centerColor(right), '青');
      expect(cropJpeg(Uint8List.fromList([1, 2]), Rect.zero), isNull);
    });
  });

  group('画面', () {
    /// 切り抜きの画面を開くボタンを出し、閉じたときの結果を返す
    Future<Uint8List? Function()> open(
      WidgetTester tester,
      Uint8List image,
    ) async {
      Uint8List? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showIconCropper(context, image);
                closed = true;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      return () {
        expect(closed, isTrue, reason: '画面が閉じていない');
        return result;
      };
    }

    testWidgets('UT-CR-06 動かさずに「決定」すると、真ん中の正方形を返す', (tester) async {
      final result = await open(tester, stripes(400, 200));
      expect(find.text('アイコンの範囲'), findsOneWidget);
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      final cropped = result()!;
      final decoded = img.decodeImage(cropped)!;
      expect(decoded.width, decoded.height);
      expect(decoded.width, 200);
      expect(centerColor(cropped), '緑');
    });

    testWidgets('UT-CR-07 右へ動かすと、左側（赤）を含む範囲になる', (tester) async {
      final result = await open(tester, stripes(400, 200));
      await tester.drag(find.byType(InteractiveViewer), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      final cropped = result()!;
      // 左の端まで動いたので、範囲の左上は赤
      final decoded = img.decodeImage(cropped)!;
      final p = decoded.getPixel(2, decoded.height ~/ 2);
      expect(p.r, greaterThan(p.g));
    });

    testWidgets('UT-CR-08 閉じると何も返さない', (tester) async {
      final result = await open(tester, stripes(400, 200));
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(result(), isNull);
    });

    testWidgets('UT-CR-09 Windows は操作の説明をマウスの言葉で出す', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await open(tester, stripes(40, 20));
      expect(find.text('ドラッグで動かし、ホイールで大きさを変えます'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
