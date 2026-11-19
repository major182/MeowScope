import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/calendar/presentation/calendar_screen.dart';
import 'package:meowscope/features/cats/presentation/vet_history.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';
import 'package:meowscope/features/records/domain/vet_detail.dart';
import 'package:meowscope/features/records/presentation/record_detail_screen.dart';
import 'package:meowscope/features/records/presentation/record_edit_screen.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');

void main() {
  group('病院の追加情報（records.detail）', () {
    test('UT-VT-01 名前と次の予定日を JSON にし、読み戻す。空のときは null（detail を空にする）', () {
      const empty = VetDetail();
      expect(empty.encode(), isNull);
      final both = VetDetail(
        hospital: 'みどり動物病院',
        nextDate: DateTime(2026, 12, 1),
      );
      expect(jsonDecode(both.encode()!), {
        'hospital': 'みどり動物病院',
        'nextDate': '2026-12-01',
      });
      // 片方だけなら、もう片方のキーを入れない
      expect(jsonDecode(const VetDetail(hospital: 'A').encode()!), {
        'hospital': 'A',
      });
      final back = VetDetail.parse(both.encode());
      expect(back.hospital, 'みどり動物病院');
      expect(back.nextDate, DateTime(2026, 12, 1));
    });

    test('UT-VT-02 異常系：空・壊れた JSON・形の違う値・空白だけの名前・日付でない値は読めるところだけ使う', () {
      expect(VetDetail.parse(null).isEmpty, isTrue);
      expect(VetDetail.parse('こわれた').isEmpty, isTrue);
      expect(VetDetail.parse('[1,2]').isEmpty, isTrue);
      expect(VetDetail.parse('{"hospital":"  "}').hospital, isNull);
      expect(VetDetail.parse('{"hospital":1}').hospital, isNull);
      final d = VetDetail.parse('{"hospital":"A","nextDate":"x"}');
      expect(d.hospital, 'A');
      expect(d.nextDate, isNull);
      // ほかの項目の detail（ご飯の例）は空として扱う
      expect(VetDetail.parse('{"note":"x"}').isEmpty, isTrue);
    });

    test('UT-VT-03 境界値：病院の名前は50文字まで（51文字は不可）。空は可', () {
      expect(validateHospital('あ' * 50), isNull);
      expect(validateHospital('あ' * 51), isNotNull);
      expect(validateHospital(' ${'あ' * 50} '), isNull);
      expect(validateHospital(''), isNull);
      expect(validateHospital(null), isNull);
    });

    test('UT-VT-04 名前の候補：新しく使った順に、重なりと名前なしを除く。入力した文字を含むものに絞る', () {
      final names = hospitalSuggestions([
        '{"hospital":"みどり動物病院"}',
        null,
        '{"nextDate":"2026-12-01"}',
        '{"hospital":"さくらペットクリニック"}',
        '{"hospital":"みどり動物病院"}',
        '{"hospital":"Blue Vet"}',
      ]);
      expect(names, ['みどり動物病院', 'さくらペットクリニック', 'Blue Vet']);
      expect(filterSuggestions(names, ''), names);
      expect(filterSuggestions(names, 'みどり'), ['みどり動物病院']);
      expect(filterSuggestions(names, 'blue'), ['Blue Vet']);
      expect(filterSuggestions(names, 'なし'), isEmpty);
    });

    test('UT-VT-05 予定の印の日：今日と未来の日だけ。猫で絞る。予定日のない記録は出さない', () {
      RecordEntry e(String cat, String? detail) => RecordEntry(
        id: cat,
        recordedAt: DateTime(2026, 11, 1),
        catName: cat,
        typeName: '病院',
        catId: cat,
        kind: 'vet',
        hasMemo: false,
        recordTypeId: 't',
        detail: detail,
      );
      final records = [
        e('c1', '{"nextDate":"2026-11-18"}'),
        e('c1', '{"nextDate":"2026-11-19"}'),
        e('c2', '{"nextDate":"2026-12-01"}'),
        e('c2', '{"hospital":"A"}'),
      ];
      final today = DateTime(2026, 11, 19, 15);
      expect(vetPlanDays(records, today), {
        DateTime(2026, 11, 19),
        DateTime(2026, 12, 1),
      });
      expect(vetPlanDays(records, today, catId: 'c1'), {
        DateTime(2026, 11, 19),
      });
    });

    test('UT-VT-06 種類：病院は量を付けず、病院の欄を出す。保存するアイコンは custom_vet、画面の絵は vet', () {
      expect(RecordKind.vet.storedIcon, 'custom_vet');
      expect(RecordKind.food.storedIcon, 'food');
      expect(typeIconValue('vet', 'custom_vet'), 'vet');
      expect(typeIconValue('food', 'food'), 'food');
      expect(typeIconValue('custom', 'custom_nail'), 'custom_nail');
      expect(
        iconAsset(typeIconValue('vet', 'custom_vet')),
        'assets/icons/vet.png',
      );
      expect(calendarAsset('vet', 'custom_vet'), vetCalendarAsset);
    });
  });

  late AppDatabase db;
  late RecordRepository repo;
  late String vetType;

  setUp(() async {
    db = memoryDatabase();
    repo = RecordRepository(db);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await repo.addStandardTypes('h1');
    vetType = (await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals('vet'))).getSingle()).id;
  });

  tearDown(() => db.close());

  /// 病院の記録を1件作る（detail を直接入れる）
  Future<String> addVet(
    String catId,
    DateTime at, {
    String? hospital,
    DateTime? next,
    String? memo,
  }) async {
    final id = await repo.addRecord(
      catId: catId,
      recordTypeId: vetType,
      author: _author,
      recordedAt: at,
    );
    await repo.updateRecord(
      id: id,
      recordedAt: at,
      level: null,
      valueNumber: null,
      memo: memo,
      author: _author,
      detail: (json: VetDetail(hospital: hospital, nextDate: next).encode()),
    );
    return id;
  }

  test('UT-VT-07 病院の記録を新しい順に読み、猫で絞る。ほかの項目と削除した記録は含めない', () async {
    final a = await addVet('c1', DateTime(2026, 11, 1), hospital: 'A');
    final b = await addVet('c2', DateTime(2026, 11, 5), hospital: 'B');
    final c = await addVet('c1', DateTime(2026, 11, 10), hospital: 'C');
    final deleted = await addVet('c1', DateTime(2026, 11, 12));
    await repo.deleteRecord(id: deleted, author: _author);
    final food = (await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals('food'))).getSingle()).id;
    await repo.addRecord(catId: 'c1', recordTypeId: food, author: _author);

    final all = await repo.watchVetRecords('h1').first;
    expect(all.map((e) => e.id), [c, b, a]);
    expect(all.first.detail, '{"hospital":"C"}');
    final mike = await repo.watchVetRecords('h1', catId: 'c1').first;
    expect(mike.map((e) => e.id), [c, a]);
  });

  test('UT-VT-08 detail を渡したときだけ書き換え、渡さなければ今の detail を残す。同期待ちに残す', () async {
    final id = await addVet('c1', DateTime(2026, 11, 1), hospital: 'A');
    Future<String?> detail() async => (await (db.select(
      db.records,
    )..where((r) => r.id.equals(id))).getSingle()).detail;

    await repo.updateRecord(
      id: id,
      recordedAt: DateTime(2026, 11, 1),
      level: null,
      valueNumber: null,
      memo: 'メモだけ',
      author: _author,
    );
    expect(await detail(), '{"hospital":"A"}');

    await repo.updateRecord(
      id: id,
      recordedAt: DateTime(2026, 11, 1),
      level: null,
      valueNumber: null,
      memo: null,
      author: _author,
      detail: (json: null),
    );
    expect(await detail(), isNull);
    expect(await db.select(db.pendingChanges).get(), isNotEmpty);
  });

  Future<void> show(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) =>
              CalendarScreen(today: DateTime(2026, 11, 19)),
        ),
        GoRoute(
          path: '/history/:cat',
          builder: (context, state) =>
              Scaffold(body: VetHistory(catId: state.pathParameters['cat']!)),
        ),
        GoRoute(
          path: '/records/:id',
          builder: (context, state) =>
              RecordDetailScreen(recordId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  RecordEditScreen(recordId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
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

  Future<RecordRow> row(String id) =>
      (db.select(db.records)..where((r) => r.id.equals(id))).getSingle();

  group('病院の詳細入力（S-12）', () {
    testWidgets('UT-VT-09 病院は量を出さず、病院の名前と次の予定日を出す。ご飯には出さない', (tester) async {
      final id = await addVet('c1', DateTime(2026, 11, 1));
      await show(tester, '/records/$id/edit');
      expect(find.text('量'), findsNothing);
      expect(find.widgetWithText(TextFormField, '病院の名前'), findsOneWidget);
      expect(find.text('次の予定日'), findsOneWidget);
      await close(tester);

      final food = (await (db.select(
        db.recordTypes,
      )..where((t) => t.kind.equals('food'))).getSingle()).id;
      final f = await repo.addRecord(
        catId: 'c1',
        recordTypeId: food,
        author: _author,
      );
      await show(tester, '/records/$f/edit');
      expect(find.text('病院の名前'), findsNothing);
      expect(find.text('次の予定日'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-VT-10 前に入れた名前を候補に出し、選んで保存すると detail に入る', (tester) async {
      await addVet('c2', DateTime(2026, 11, 1), hospital: 'みどり動物病院');
      await addVet('c2', DateTime(2026, 11, 2), hospital: 'さくらペットクリニック');
      final id = await addVet('c1', DateTime(2026, 11, 3));
      await show(tester, '/records/$id/edit');

      await tester.enterText(find.widgetWithText(TextFormField, '病院の名前'), 'みど');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'さくらペットクリニック'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'みどり動物病院'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(VetDetail.parse((await row(id)).detail).hospital, 'みどり動物病院');
      await close(tester);
    });

    testWidgets('UT-VT-11 境界値：51文字目は入力欄に入らず、50文字で保存する', (tester) async {
      final id = await addVet('c1', DateTime(2026, 11, 3));
      await show(tester, '/records/$id/edit');

      await tester.enterText(
        find.widgetWithText(TextFormField, '病院の名前'),
        'あ' * 51,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(VetDetail.parse((await row(id)).detail).hospital, 'あ' * 50);
      await close(tester);
    });

    testWidgets('UT-VT-12 次の予定日：今日より前は選べず、選んで保存できる。「次の予定日を外す」で消せる', (
      tester,
    ) async {
      final today = DateTime.now();
      final id = await addVet(
        'c1',
        DateTime(today.year, today.month, today.day),
      );
      await show(tester, '/records/$id/edit');

      await tester.tap(find.text('選ぶ'));
      await tester.pumpAndSettle();
      // 今日より前の日は押せない（今日が1日なら前の日はこの月にない）
      if (today.day > 1) {
        final yesterday = find.text('${today.day - 1}');
        await tester.tap(yesterday.last, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      // 今日の日付を選んで OK
      await tester.tap(find.text('${today.day}').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.text('${today.year}/${today.month}/${today.day}'),
        findsOneWidget,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        VetDetail.parse((await row(id)).detail).nextDate,
        DateTime(today.year, today.month, today.day),
      );
      await close(tester);

      await show(tester, '/records/$id/edit');
      await tester.tap(find.byTooltip('次の予定日を外す'));
      await tester.pumpAndSettle();
      expect(find.text('選ぶ'), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await row(id)).detail, isNull);
      await close(tester);
    });
  });

  testWidgets('UT-VT-13 記録の詳細（S-22）に病院の名前と次の予定日を出す', (tester) async {
    final id = await addVet(
      'c1',
      DateTime(2026, 11, 3),
      hospital: 'みどり動物病院',
      next: DateTime(2026, 12, 1),
    );
    await show(tester, '/records/$id');

    expect(find.text('みどり動物病院'), findsOneWidget);
    expect(find.text('2026/12/1'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'UT-VT-14 カレンダー：次の予定日（今日と未来）に病院の予定の印。過ぎた日には出さない。1匹に絞ると、その猫の予定だけ',
    (tester) async {
      await addVet('c1', DateTime(2026, 11, 1), next: DateTime(2026, 11, 18));
      await addVet('c1', DateTime(2026, 11, 2), next: DateTime(2026, 11, 19));
      await addVet('c2', DateTime(2026, 11, 3), next: DateTime(2026, 11, 25));
      await show(tester, '/calendar');

      Finder plan(int day) => find.descendant(
        of: find.byKey(ValueKey('day-11-$day')),
        matching: find.bySemanticsLabel('病院の予定'),
      );
      expect(plan(18), findsNothing);
      expect(plan(19), findsOneWidget);
      expect(plan(25), findsOneWidget);

      await tester.tap(find.text('全員'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ミケ').last);
      await tester.pumpAndSettle();
      expect(plan(19), findsOneWidget);
      expect(plan(25), findsNothing);
      await close(tester);
    },
  );

  testWidgets('UT-VT-15 猫のプロフィールの病院の履歴：その猫の病院の記録を新しい順に出し、押すと詳細へ。なければ案内', (
    tester,
  ) async {
    await addVet(
      'c1',
      DateTime(2026, 10, 1),
      hospital: 'A病院',
      memo: '1行目\n2行目',
    );
    final b = await addVet('c1', DateTime(2026, 11, 1));
    await addVet('c2', DateTime(2026, 11, 2), hospital: 'ほかの猫');
    await show(tester, '/history/c1');

    expect(find.text('ほかの猫'), findsNothing);
    final older = tester.getTopLeft(find.text('A病院')).dy;
    // 病院の名前がない記録は項目の名前を出す
    final newer = tester.getTopLeft(find.text('病院')).dy;
    expect(newer, lessThan(older));
    expect(find.text('1行目'), findsOneWidget);
    expect(find.text('2行目'), findsNothing);

    await tester.tap(find.text('2026/11/1'));
    await tester.pumpAndSettle();
    expect(find.text('記録の詳細'), findsOneWidget);
    await close(tester);

    await show(tester, '/history/c9');
    expect(find.text('まだ記録はありません'), findsOneWidget);
    await close(tester);
    expect(b, isNotEmpty);
  });
}
