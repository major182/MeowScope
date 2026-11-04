import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/widgets/readable_width.dart';

void main() {
  Future<EdgeInsets> paddingAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late EdgeInsets padding;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          padding = readablePadding(context, 16);
          return const SizedBox();
        },
      ),
    );
    return padding;
  }

  testWidgets(
    'UT-RW-01 狭い画面は上下左右とも決めた余白。中身が 640px を超える幅からは左右の余白を増やす（境界値 672・673px）',
    (tester) async {
      expect(await paddingAt(tester, 400), const EdgeInsets.all(16));
      // 640 + 16 × 2 = 672 までは決めた余白のまま
      expect(await paddingAt(tester, 672), const EdgeInsets.all(16));
      expect(
        await paddingAt(tester, 673),
        const EdgeInsets.fromLTRB(16.5, 16, 16.5, 16),
      );
      final wide = await paddingAt(tester, 1280);
      expect((wide.left, wide.right, wide.top), (320, 320, 16));
      expect(1280 - wide.horizontal, readableMaxWidth);
    },
  );
}
