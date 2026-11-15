import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/photos/presentation/photo_viewer.dart';
import 'package:meowscope/features/photos/presentation/photo_widgets.dart';

import '../../helpers/test_db.dart';
import 'photo_test.dart' show addRecordRow;
import 'photo_widgets_test.dart' show FakePhotoRepository, insertPhoto;

/// 写真の全画面表示（F-RC-06、S-22）
void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await addRecordRow(db, 'r1');
  });
  tearDown(() => db.close());

  /// 写真を [count] 枚付けた記録で、[child]（詳細の写真か詳細入力の写真の欄）を出す
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    int count = 3,
    PhotoImage Function(RecordPhotoRow)? image,
  }) async {
    for (var i = 1; i <= count; i++) {
      await insertPhoto(db, 'p$i', i);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoRepositoryProvider.overrideWithValue(FakePhotoRepository(db)),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
          photoImageProvider.overrideWith(
            (ref, photo) async => image?.call(photo) ?? PhotoBytes(_png),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 開いた写真を押して、全画面を出す
  Future<void> openAt(WidgetTester tester, int index) async {
    await tester.tap(find.byType(PhotoThumb).at(index));
    await tester.pumpAndSettle();
  }

  /// 今出ている写真の拡大の倍率
  double scale(WidgetTester tester) {
    final viewers = tester.widgetList<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    // めくった後は前後の写真も作られていることがあるので、いちばん大きい倍率を見る
    return viewers
        .map((v) => v.transformationController!.value.getMaxScaleOnAxis())
        .reduce((a, b) => a > b ? a : b);
  }

  testWidgets('UT-PV-01 詳細の写真を押すと、その写真から全画面で開き、閉じると戻る', (tester) async {
    await show(tester, const PhotoGallery(recordId: 'r1'));
    await openAt(tester, 1);
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.byType(PhotoThumb), findsNWidgets(3));
  });

  testWidgets('UT-PV-02 左右にめくる：指・前後のボタン・矢印のキー。端ではその向きのボタンを出さない', (
    tester,
  ) async {
    await show(tester, const PhotoGallery(recordId: 'r1'));
    await openAt(tester, 0);
    // 最初の写真：前のボタンはない
    expect(find.byTooltip('前の写真'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('次の写真'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    // 最後の写真：次のボタンはない。矢印のキーでも先へ進まない（境界）
    expect(find.byTooltip('次の写真'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('前の写真'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('UT-PV-03 ダブルタップで拡大し、拡大中はめくらない。もう一度で元に戻る', (tester) async {
    await show(tester, const PhotoGallery(recordId: 'r1'));
    await openAt(tester, 0);
    expect(scale(tester), 1);

    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(scale(tester), closeTo(photoDoubleTapScale, 0.01));

    // 拡大中に横へ動かしても、次の写真へは行かない
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(scale(tester), closeTo(1, 0.01));
  });

  testWidgets('UT-PV-04 Windows：マウスのホイールで拡大する', (tester) async {
    await show(tester, const PhotoGallery(recordId: 'r1'), count: 1);
    await openAt(tester, 0);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
    await tester.pumpAndSettle();
    expect(scale(tester), greaterThan(1));
  });

  testWidgets('UT-PV-05 1枚だけなら、何枚目かの表示と前後のボタンを出さない', (tester) async {
    await show(tester, const PhotoGallery(recordId: 'r1'), count: 1);
    await openAt(tester, 0);
    expect(find.textContaining(' / '), findsNothing);
    expect(find.byTooltip('前の写真'), findsNothing);
    expect(find.byTooltip('次の写真'), findsNothing);
  });

  testWidgets('UT-PV-06 詳細入力の写真も全画面で開く。角の「写真を外す」は外すだけで開かない', (tester) async {
    await show(tester, const PhotoEditor(recordId: 'r1'), count: 2);
    await tester.tap(find.byTooltip('写真を外す').first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.byType(PhotoThumb), findsOneWidget);

    await openAt(tester, 0);
    expect(find.byType(PhotoViewer), findsOneWidget);
  });

  for (final (image, text) in [
    (const PhotoOffline(), 'オンラインで表示できます'),
    (const PhotoNotYetUploaded(), 'まだ届いていません'),
  ]) {
    testWidgets('UT-PV-07 取れない写真は、全画面でも「$text」と出す（BR-28）', (tester) async {
      await show(
        tester,
        const PhotoGallery(recordId: 'r1'),
        count: 1,
        image: (_) => image,
      );
      await openAt(tester, 0);
      // 小さな表示と全画面の両方に出る
      expect(
        find.descendant(
          of: find.byType(PhotoViewer),
          matching: find.text(text),
        ),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  }
}

/// 1×1 の透明な PNG
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
