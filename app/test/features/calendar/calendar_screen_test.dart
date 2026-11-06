import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/calendar/presentation/calendar_screen.dart';
import 'package:meowscope/features/calendar/presentation/day_records.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/icons/icon_avatar.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');
final _today = DateTime(2026, 11, 2);

void main() {
  late AppDatabase db;
  late DateTime now;
  late RecordRepository repo;

  setUp(() async {
    db = memoryDatabase();
    now = _today;
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await repo.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  /// 記録を1件作る。ウィジェットのテストの中では DB の見張りが進まないので、直接読む
  Future<String> record(String catId, String kind, DateTime at) async {
    final type = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals(kind))).getSingle();
    now = at;
    return repo.addRecord(catId: catId, recordTypeId: type.id, author: _author);
  }

  Future<void> show(
    WidgetTester tester,
    Widget home, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => home),
        GoRoute(
          path: '/days/:date',
          builder: (context, state) => Text(
            '日別：${state.pathParameters['date']} ${state.uri.queryParameters['cat']}',
          ),
        ),
        GoRoute(
          path: '/records/:id',
          builder: (context, state) => Text('詳細：${state.pathParameters['id']}'),
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

  Finder cell(int month, int day) => find.byKey(ValueKey('day-$month-$day'));

  /// セルの中のイラスト（name は assets/icons のファイル名）
  Finder inCell(int month, int day, String name) => find.descendant(
    of: cell(month, day),
    matching: find.image(AssetImage('assets/icons/$name.png')),
  );

  group('カレンダー（S-20）', () {
    testWidgets('UT-CS-01 今月を日曜始まりの6行7列で出す', (tester) async {
      await show(tester, CalendarScreen(today: _today));

      expect(find.text('2026年11月'), findsOneWidget);
      // 11月1日は日曜なので左上、12月12日が右下
      expect(tester.getTopLeft(cell(11, 1)).dx, 0);
      expect(cell(12, 12), findsOneWidget);
      expect(cell(12, 13), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CS-02 記録の種類とメモの有無を、その日のセルに出す', (tester) async {
      final id = await record('c1', 'food', DateTime(2026, 11, 2, 8));
      await record('c2', 'vomit', DateTime(2026, 11, 2, 12));
      await repo.updateRecord(
        id: id,
        recordedAt: DateTime(2026, 11, 2, 8),
        level: null,
        valueNumber: null,
        memo: 'あり',
        author: _author,
      );
      await show(tester, CalendarScreen(today: _today));

      expect(inCell(11, 2, 'cal_food'), findsOneWidget);
      expect(inCell(11, 2, 'cal_vomit'), findsOneWidget);
      expect(inCell(11, 2, 'cal_memo'), findsOneWidget);
      expect(inCell(11, 3, 'cal_food'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CS-03 1匹に絞り込むと、その猫の記録の印だけを出す', (tester) async {
      await record('c1', 'food', DateTime(2026, 11, 2, 8));
      await record('c2', 'vomit', DateTime(2026, 11, 2, 12));
      await show(tester, CalendarScreen(today: _today));

      await tester.tap(find.text('全員'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('タマ').last);
      await tester.pumpAndSettle();

      expect(inCell(11, 2, 'cal_vomit'), findsOneWidget);
      expect(inCell(11, 2, 'cal_food'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CS-04 前後の月へ移動する。年をまたぐ', (tester) async {
      await show(tester, CalendarScreen(today: DateTime(2026, 12, 15)));

      await tester.tap(find.byTooltip('次の月'));
      await tester.pumpAndSettle();
      expect(find.text('2027年1月'), findsOneWidget);

      await tester.tap(find.byTooltip('前の月'));
      await tester.tap(find.byTooltip('前の月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年11月'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CS-05 週の始まりを月曜にすると、月曜から並ぶ', (tester) async {
      await SettingsRepository(db).setWeekStart(WeekStart.monday);
      await show(tester, CalendarScreen(today: _today));

      // 11月1日は日曜なので、月曜始まりでは1行目の右端
      expect(tester.getTopLeft(cell(10, 26)).dx, 0);
      expect(
        tester.getTopLeft(cell(11, 1)).dy,
        tester.getTopLeft(cell(10, 26)).dy,
      );
      await close(tester);
    });

    testWidgets('UT-CS-06 狭い幅では、日を押すと日別一覧を開く（絞り込みを引き継ぐ）', (tester) async {
      await show(tester, CalendarScreen(today: _today));
      await tester.tap(cell(11, 5));
      await tester.pumpAndSettle();
      expect(find.text('日別：2026-11-05 null'), findsOneWidget);
      await close(tester);

      await show(tester, CalendarScreen(today: _today));
      await tester.tap(find.text('全員'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ミケ').last);
      await tester.pumpAndSettle();
      await tester.tap(cell(11, 5));
      await tester.pumpAndSettle();
      expect(find.text('日別：2026-11-05 c1'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CS-07 広い幅では、日別一覧を右に並べ、押した日に切り替える', (tester) async {
      await record('c1', 'food', DateTime(2026, 11, 5, 8));
      await show(tester, CalendarScreen(today: _today), width: 1000);

      expect(find.text('11月 2日'), findsOneWidget);
      expect(find.text('この日の記録はありません'), findsOneWidget);

      await tester.tap(cell(11, 5));
      await tester.pumpAndSettle();
      expect(find.text('11月 5日'), findsOneWidget);
      expect(find.text('ミケ　ご飯'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CS-08 広い幅で日別一覧を次の月へ進めると、カレンダーも移る', (tester) async {
      await show(
        tester,
        CalendarScreen(today: DateTime(2026, 11, 30)),
        width: 1000,
      );

      await tester.tap(find.byTooltip('次の日'));
      await tester.pumpAndSettle();

      expect(find.text('12月 1日'), findsOneWidget);
      expect(find.text('2026年12月'), findsOneWidget);
      await close(tester);
    });
  });

  group('日別一覧（S-21）', () {
    testWidgets('UT-CS-09 その日の記録を時刻の順に出し、メモの印を付ける', (tester) async {
      final id = await record('c1', 'vomit', DateTime(2026, 11, 2, 12));
      await record('c2', 'urine', DateTime(2026, 11, 2, 9, 30));
      await record('c1', 'food', DateTime(2026, 11, 3, 8));
      await repo.updateRecord(
        id: id,
        recordedAt: DateTime(2026, 11, 2, 12),
        level: null,
        valueNumber: null,
        memo: '毛玉',
        author: _author,
      );
      await show(tester, DayListScreen(day: _today));

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles, hasLength(2));
      // 名前はアイコンと並べて出す（画面設計書 1章）。文はその中にある
      String titleOf(ListTile tile) => tester
          .widget<Text>(
            find.descendant(
              of: find.byWidget(tile.title!),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(titleOf(tiles[0]), 'タマ　おしっこ');
      expect(titleOf(tiles[1]), 'ミケ　吐いた');
      expect(tiles[0].trailing, isNull);
      expect(
        find.image(const AssetImage('assets/icons/cal_memo.png')),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('UT-CS-10 前後の日へ移動する。月をまたぐ', (tester) async {
      await record('c1', 'food', DateTime(2026, 10, 31, 8));
      await show(tester, DayListScreen(day: DateTime(2026, 11, 1)));
      expect(find.text('この日の記録はありません'), findsOneWidget);

      await tester.tap(find.byTooltip('前の日'));
      await tester.pumpAndSettle();
      expect(find.text('10月 31日'), findsOneWidget);
      expect(find.text('ミケ　ご飯'), findsOneWidget);

      await tester.tap(find.byTooltip('次の日'));
      await tester.pump();
      await tester.tap(find.byTooltip('次の日'));
      await tester.pumpAndSettle();
      expect(find.text('11月 2日'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CS-11 猫で絞り込んだ一覧を出す', (tester) async {
      await record('c1', 'food', DateTime(2026, 11, 2, 8));
      await record('c2', 'food', DateTime(2026, 11, 2, 9));
      await show(tester, DayListScreen(day: _today, catId: 'c2'));

      expect(find.text('タマ　ご飯'), findsOneWidget);
      expect(find.text('ミケ　ご飯'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CS-12 記録を押すと、その記録の詳細へ進む', (tester) async {
      final id = await record('c1', 'food', DateTime(2026, 11, 2, 8));
      await show(tester, DayListScreen(day: _today));

      await tester.tap(find.text('ミケ　ご飯'));
      await tester.pumpAndSettle();

      expect(find.text('詳細：$id'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CS-13 写真がある記録には写真の印を付け、ない記録と削除した写真には付けない。猫はアイコンと並べる', (
      tester,
    ) async {
      final withPhoto = await record('c1', 'vomit', DateTime(2026, 11, 2, 12));
      final deleted = await record('c2', 'urine', DateTime(2026, 11, 2, 9, 30));
      await record('c1', 'food', DateTime(2026, 11, 2, 8));
      Future<void> photo(String id, String recordId, {DateTime? deletedAt}) =>
          db
              .into(db.recordPhotos)
              .insert(
                RecordPhotosCompanion.insert(
                  id: id,
                  createdAt: testTime,
                  updatedAt: testTime,
                  recordId: recordId,
                  sortOrder: 1,
                  deletedAt: Value(deletedAt),
                ),
              );
      await photo('p1', withPhoto);
      await photo('p2', deleted, deletedAt: testTime);
      await show(tester, DayListScreen(day: _today));

      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      final photoTile = find.ancestor(
        of: find.byIcon(Icons.photo_camera_outlined),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: photoTile, matching: find.text('ミケ　吐いた')),
        findsOneWidget,
      );
      expect(find.byType(IconAvatar), findsNWidgets(3));
      await close(tester);
    });
  });

  testWidgets(
    'UT-CS-14 猫の誕生日の日のセルに誕生日の印を出す。お別れの猫と生年月日のない猫には出さない（F-VW-05、BR-32）',
    (tester) async {
      await (db.update(db.cats)..where((c) => c.id.equals('c1'))).write(
        CatsCompanion(birthDate: Value(DateTime.utc(2023, 11, 10))),
      );
      await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
        CatsCompanion(
          birthDate: Value(DateTime.utc(2022, 11, 20)),
          status: const Value('farewell'),
        ),
      );
      await show(tester, CalendarScreen(today: _today));

      expect(find.byIcon(Icons.cake_outlined), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('day-11-10')),
          matching: find.byIcon(Icons.cake_outlined),
        ),
        findsOneWidget,
      );
      await close(tester);
    },
  );
}
