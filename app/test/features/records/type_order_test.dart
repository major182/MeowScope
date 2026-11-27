import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/calendar/presentation/day_record_add.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/custom_type.dart';
import 'package:meowscope/features/records/domain/type_order.dart';
import 'package:meowscope/features/records/presentation/home_screen.dart';
import 'package:meowscope/features/records/presentation/record_types_screen.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');

String _id(String s) => s;

void main() {
  group('並び順の当てはめ（BR-36）', () {
    test('UT-TO-01 並べ替えていなければ、登録の順のまま', () {
      expect(applyTypeOrder(['a', 'b', 'c'], const [], _id), ['a', 'b', 'c']);
    });

    test('UT-TO-02 並び順の順に並べ、並び順にない項目（後から増えた項目）は登録の順で最後に置く', () {
      expect(applyTypeOrder(['a', 'b', 'c'], ['c', 'a', 'b'], _id), [
        'c',
        'a',
        'b',
      ]);
      expect(applyTypeOrder(['a', 'b', 'c', 'd', 'e'], ['c', 'a'], _id), [
        'c',
        'a',
        'b',
        'd',
        'e',
      ]);
    });

    test('UT-TO-03 異常系：並び順にあって項目にない ID（消えた項目）は無視する', () {
      expect(applyTypeOrder(['a', 'b'], ['x', 'b', 'y', 'a'], _id), ['b', 'a']);
    });

    test('UT-TO-04 保存した値を読む。未設定・壊れた値・配列でない値・文字でない要素は扱わない', () {
      expect(parseTypeOrder(null), isEmpty);
      expect(parseTypeOrder('["b","a"]'), ['b', 'a']);
      expect(parseTypeOrder('こわれた'), isEmpty);
      expect(parseTypeOrder('{"a":1}'), isEmpty);
      expect(parseTypeOrder('["a",1,null,"b"]'), ['a', 'b']);
    });

    test('UT-TO-05 境界値：先頭を最後へ、最後を先頭へ、同じ位置へ動かす', () {
      const ids = ['a', 'b', 'c', 'd'];
      expect(moveTypeOrder(ids, 0, 3), ['b', 'c', 'd', 'a']);
      expect(moveTypeOrder(ids, 3, 0), ['d', 'a', 'b', 'c']);
      expect(moveTypeOrder(ids, 1, 2), ['a', 'c', 'b', 'd']);
      expect(moveTypeOrder(ids, 2, 2), ids);
    });
  });

  late AppDatabase db;
  late RecordRepository repo;
  late SettingsRepository settings;
  late Map<String, String> ids;

  setUp(() async {
    db = memoryDatabase();
    repo = RecordRepository(db);
    settings = SettingsRepository(db);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await repo.addStandardTypes('h1');
    ids = {for (final t in await db.select(db.recordTypes).get()) t.name: t.id};
  });

  tearDown(() => db.close());

  Future<String> addCustom(String name) async {
    final id = await repo.addCustomType(
      householdId: 'h1',
      userId: 'u1',
      name: name,
      icon: CustomIcon.treat.value,
    );
    ids[name] = id;
    return id;
  }

  test('UT-TO-06 並び順はおうちごとに端末の状態へ置き、同期待ちに入れない', () async {
    await db.delete(db.pendingChanges).go();
    await settings.setTypeOrder('h1', ['b', 'a']);
    await settings.setTypeOrder('h2', ['x']);

    expect(await settings.watchTypeOrder('h1').first, ['b', 'a']);
    expect(await settings.watchTypeOrder('h2').first, ['x']);
    expect(await settings.watchTypeOrder('h3').first, isEmpty);
    final row = await (db.select(
      db.appStates,
    )..where((s) => s.key.equals('settings.recordTypeOrder.h1'))).getSingle();
    expect(row.value, '["b","a"]');
    expect(await db.select(db.pendingChanges).get(), isEmpty);
  });

  /// 保存した並び順を直接読む（ウィジェットのテストの中では DB の見張りが進まないため）
  Future<List<String>> savedOrder() async {
    final row =
        await (db.select(db.appStates)..where(
              (s) => s.key.equals(SettingsRepository.typeOrderKey('h1')),
            ))
            .getSingleOrNull();
    return parseTypeOrder(row?.value);
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => screen)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// 画面の上から順に、名前の並びを返す
  List<String> order(WidgetTester tester, Finder within, List<String> names) {
    final found = [
      for (final n in names)
        if (find
            .descendant(of: within, matching: find.text(n))
            .evaluate()
            .isNotEmpty)
          n,
    ];
    Offset at(String n) => tester.getTopLeft(
      find.descendant(of: within, matching: find.text(n)).first,
    );
    found.sort((a, b) {
      final pa = at(a);
      final pb = at(b);
      return pa.dy != pb.dy ? pa.dy.compareTo(pb.dy) : pa.dx.compareTo(pb.dx);
    });
    return found;
  }

  group('記録項目の設定（S-43）の並べ替え', () {
    testWidgets('UT-TO-07 標準の項目も含めてすべてにつまみがあり、動かすとこの端末の並び順に残す', (tester) async {
      await addCustom('おやつ');
      await show(tester, const RecordTypesScreen());
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(10));

      // つまみで「おやつ」（10番目）を先頭へ動かしたときの呼び出し
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(9, 0);
      await tester.pumpAndSettle();

      final saved = await savedOrder();
      expect(saved.first, ids['おやつ']);
      expect(saved, hasLength(10));
      expect(
        order(tester, find.byType(ReorderableListView), ['おやつ', 'ご飯（標準）']),
        ['おやつ', 'ご飯（標準）'],
      );
      await close(tester);
    });

    testWidgets('UT-TO-08 つまみを指でドラッグして並べ替えられる', (tester) async {
      await show(tester, const RecordTypesScreen());
      final handle = find.byIcon(Icons.drag_handle).first;
      final height = tester.getSize(find.byType(ListTile).first).height;

      // 「ご飯」のつまみを下へドラッグする（どこまで動くかは Flutter の判定に任せ、下へ動いたことを確かめる）
      await tester.drag(handle, Offset(0, height * 2.5));
      await tester.pumpAndSettle();

      final saved = await savedOrder();
      expect(saved.first, ids['水']);
      expect(saved.indexOf(ids['ご飯']!), greaterThan(0));
      expect(saved, hasLength(9));
      await close(tester);
    });

    testWidgets('UT-TO-09 非表示の項目も並べ替えの一覧に出す', (tester) async {
      final hidden = await addCustom('爪切り');
      await repo.setTypeHidden(id: hidden, userId: 'u1', hidden: true);
      await settings.setTypeOrder('h1', [hidden]);
      await show(tester, const RecordTypesScreen());

      expect(
        order(tester, find.byType(ReorderableListView), ['爪切り', 'ご飯（標準）']),
        ['爪切り', 'ご飯（標準）'],
      );
      expect(find.text('非表示中'), findsOneWidget);
      await close(tester);
    });
  });

  group('ホーム（S-10）の並びと大きさ', () {
    setUp(() async {
      await addCustom('おやつ');
      await addCustom('爪切り');
    });

    testWidgets('UT-TO-10 Android：並び順で出し、上2段（8つ）は通常、9つ目から半分の大きさ', (
      tester,
    ) async {
      await settings.setTypeOrder('h1', [ids['おやつ']!, ids['体重']!]);
      await show(tester, const HomeScreen());

      final big = find.byType(GridView).first;
      final small = find.byKey(const ValueKey('small-type-buttons'));
      expect(
        find.descendant(of: big, matching: find.byType(RecordTypeButton)),
        findsNWidgets(8),
      );
      expect(
        find.descendant(of: small, matching: find.byType(RecordTypeButton)),
        findsNWidgets(3),
      );
      // 先頭はおやつ、次に体重、あとは登録の順。ブラシ・病院・爪切りが半分の大きさへ
      expect(order(tester, big, ['おやつ', '体重', 'ご飯']), ['おやつ', '体重', 'ご飯']);
      expect(order(tester, small, ['ブラシ', '病院', '爪切り']), ['ブラシ', '病院', '爪切り']);
      final bigSize = tester.getSize(
        find.descendant(of: big, matching: find.byType(RecordTypeButton)).first,
      );
      final smallSize = tester.getSize(
        find
            .descendant(of: small, matching: find.byType(RecordTypeButton))
            .first,
      );
      expect(smallSize.width, lessThan(bigSize.width * 0.6));
      await close(tester);
    });

    testWidgets('UT-TO-11 境界値：項目がちょうど8つなら、半分の大きさの段を出さない', (tester) async {
      // 8つにする：病院がまだ同期で届いていない今あるおうち（BR-37）で、独自の項目を2つとも非表示に
      await (db.delete(
        db.recordTypes,
      )..where((t) => t.kind.equals('vet'))).go();
      await repo.setTypeHidden(id: ids['おやつ']!, userId: 'u1', hidden: true);
      await repo.setTypeHidden(id: ids['爪切り']!, userId: 'u1', hidden: true);
      await show(tester, const HomeScreen());

      expect(find.byType(RecordTypeButton), findsNWidgets(8));
      expect(find.byKey(const ValueKey('small-type-buttons')), findsNothing);
      await close(tester);
    });

    testWidgets('UT-TO-12 Windows：並び順は使い、大きさは常に通常', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await settings.setTypeOrder('h1', [ids['爪切り']!]);
      await show(tester, const HomeScreen());

      expect(find.byKey(const ValueKey('small-type-buttons')), findsNothing);
      expect(find.byType(RecordTypeButton), findsNWidgets(11));
      expect(order(tester, find.byType(GridView), ['爪切り', 'ご飯']), [
        '爪切り',
        'ご飯',
      ]);
      await close(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('UT-TO-13 開き直しても並び順が残る', (tester) async {
      await show(tester, const RecordTypesScreen());
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(7, 0);
      await tester.pumpAndSettle();
      await close(tester);

      // 画面を閉じた後に、ホームを開き直す
      await show(tester, const HomeScreen());
      expect(order(tester, find.byType(GridView).first, ['ブラシ', 'ご飯']), [
        'ブラシ',
        'ご飯',
      ]);
      await close(tester);
    });

    testWidgets('UT-TO-14 日付からの記録（S-24）も同じ並び順で、大きさは常に通常', (tester) async {
      await settings.setTypeOrder('h1', [ids['爪切り']!]);
      await show(tester, DayRecordAddScreen(day: DateTime(2000, 1, 1)));

      expect(find.byType(RecordTypeButton), findsNWidgets(11));
      expect(order(tester, find.byType(GridView), ['爪切り', 'ご飯']), [
        '爪切り',
        'ご飯',
      ]);
      await close(tester);
    });
  });
}
