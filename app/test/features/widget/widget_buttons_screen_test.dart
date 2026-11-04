import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/widget/presentation/widget_buttons_screen.dart';

import '../../helpers/test_db.dart';

const _session = Session(
  author: Author(id: 'u1', name: 'はる'),
  householdId: 'h1',
);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await addHousehold(db, 'h1');
    await RecordRepository(db).addStandardTypes('h1');
  });
  tearDown(() => db.close());

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: const MaterialApp(home: WidgetButtonsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> addButton(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'ボタンを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SimpleDialogOption, name));
    await tester.pumpAndSettle();
  }

  List<String> names(WidgetTester tester) => [
    for (final e
        in find
            .descendant(of: find.byType(Card), matching: find.byType(Text))
            .evaluate())
      if ((e.widget as Text).data != '削除') (e.widget as Text).data!,
  ];

  testWidgets('UT-WB-08 ボタンがなければその旨を出し、選んだ項目を追加する。追加済みの項目は選択に出さない', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('ボタンがありません'), findsOneWidget);

    await addButton(tester, 'ご飯');
    expect(names(tester), ['ご飯']);
    expect(find.text('ボタンがありません'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ボタンを追加'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SimpleDialogOption, 'ご飯'), findsNothing);
    expect(find.widgetWithText(SimpleDialogOption, '水'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(names(tester), ['ご飯']);
    await close(tester);
  });

  testWidgets('UT-WB-09 境界値：4つで「ボタンを追加」を押せなくなり、削除すると戻る', (tester) async {
    await show(tester);
    for (final name in ['ご飯', '水', '薬']) {
      await addButton(tester, name);
    }
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ボタンを追加'))
          .enabled,
      isTrue,
    );
    await addButton(tester, 'おしっこ');
    expect(names(tester), ['ご飯', '水', '薬', 'おしっこ']);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ボタンを追加'))
          .enabled,
      isFalse,
    );
    expect(find.text('ボタンは4つまでです'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '削除').first);
    await tester.pumpAndSettle();
    expect(names(tester), ['水', '薬', 'おしっこ']);
    expect(find.text('ボタンは4つまでです'), findsNothing);
    await close(tester);
  });

  testWidgets('UT-WB-10 つまみをドラッグして並べ替える', (tester) async {
    await show(tester);
    await addButton(tester, 'ご飯');
    await addButton(tester, '水');

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(names(tester), ['水', 'ご飯']);
    await close(tester);
  });

  testWidgets('UT-WB-11 非表示の項目のボタンには「非表示中」と出す', (tester) async {
    final id = await RecordRepository(db).addCustomType(
      householdId: 'h1',
      userId: 'u1',
      name: '通院',
      icon: 'custom_vet',
    );
    await show(tester);
    await addButton(tester, '通院');
    await (db.update(db.recordTypes)..where((t) => t.id.equals(id))).write(
      const RecordTypesCompanion(hidden: Value(true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('非表示中'), findsOneWidget);
    await close(tester);
  });
}
