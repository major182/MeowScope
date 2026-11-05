import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/app/main_shell.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../helpers/test_db.dart';

const _session = Session(
  author: Author(id: 'u1', name: 'はる'),
  householdId: 'h1',
);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await addHousehold(db, 'h1');
  });
  tearDown(() => db.close());

  Future<void> show(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('UT-SH-01 最初はホームを出し、4つのメニューを並べる', (tester) async {
    await show(tester, 400);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    for (final label in ['ホーム', 'カレンダー', '統計', '設定']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    await close(tester);
  });

  testWidgets('UT-SH-02 メニューで画面を切り替える', (tester) async {
    await show(tester, 400);

    for (final (index, label) in [
      (1, 'カレンダー'),
      (2, '統計'),
      (3, '設定'),
      (0, 'ホーム'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      // ホームの見出しはおうち名（S-10）、ほかは画面の名前
      expect(
        find.widgetWithText(AppBar, label == 'ホーム' ? 'みけ家' : label),
        findsOneWidget,
      );
    }
    await close(tester);
  });

  testWidgets('UT-SH-03 境界値：幅 899px は下部メニュー', (tester) async {
    await show(tester, wideLayoutWidth - 1);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await close(tester);
  });

  testWidgets('UT-SH-04 境界値：幅 900px は左メニューで、切り替えられる', (tester) async {
    await show(tester, wideLayoutWidth);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('統計'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      2,
    );
    expect(find.widgetWithText(AppBar, '統計'), findsOneWidget);
    await close(tester);
  });
}
