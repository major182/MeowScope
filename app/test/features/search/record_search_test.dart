import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/app/router.dart' show createRouter;
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/core/today.dart';
import 'package:meowscope/features/calendar/presentation/calendar_screen.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/search/domain/record_search.dart';
import 'package:meowscope/features/search/presentation/search_screen.dart';
import 'package:meowscope/features/sync/presentation/sync_controller.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');
final _now = DateTime(2026, 11, 19, 10, 30);

/// 同期を呼んだ回数を数える（テストの側の差し替え）
class _FakeSync extends SyncController {
  static var calls = 0;

  @override
  Future<void> sync() async => calls++;
}

SearchQuery q({
  String words = '',
  String? typeId,
  String? catId,
  DateTime? from,
  DateTime? to,
}) => (words: words, recordTypeId: typeId, catId: catId, from: from, to: to);

void main() {
  group('言葉と期間の扱い（F-VW-03）', () {
    test('UT-SR-01 言葉は半角・全角の空白で分け、空の言葉は除く', () {
      expect(splitWords(''), isEmpty);
      expect(splitWords('   '), isEmpty);
      expect(splitWords('毛玉 吐いた'), ['毛玉', '吐いた']);
      expect(splitWords(' 毛玉　　吐いた  '), ['毛玉', '吐いた']);
    });

    test('UT-SR-02 メモはすべての言葉を含めば当たる。英字は大文字・小文字を区別しない。メモなしは言葉があれば外れる', () {
      expect(matchesWords('毛玉を吐いた', ['毛玉', '吐いた']), isTrue);
      expect(matchesWords('毛玉を吐いた', ['毛玉', '下痢']), isFalse);
      expect(matchesWords('Vet で検査', ['vet']), isTrue);
      expect(matchesWords(null, ['毛玉']), isFalse);
      expect(matchesWords(null, []), isTrue);
    });

    test('UT-SR-03 境界値：期間は始めの日の0時から、終わりの日の23時59分まで含む', () {
      final from = DateTime(2026, 11, 2);
      final to = DateTime(2026, 11, 3);
      expect(inPeriod(DateTime(2026, 11, 1, 23, 59), from, to), isFalse);
      expect(inPeriod(DateTime(2026, 11, 2), from, to), isTrue);
      expect(inPeriod(DateTime(2026, 11, 3, 23, 59), from, to), isTrue);
      expect(inPeriod(DateTime(2026, 11, 4), from, to), isFalse);
      // 片方だけ
      expect(inPeriod(DateTime(2000), null, to), isTrue);
      expect(inPeriod(DateTime(2099), from, null), isTrue);
    });

    test('UT-SR-04 当たった範囲は前から順に、重なりと隣り合いをまとめる。大文字・小文字を区別しない', () {
      expect(matchRanges('毛玉と毛玉', ['毛玉']), [
        (start: 0, end: 2),
        (start: 3, end: 5),
      ]);
      expect(matchRanges('abcd', ['ab', 'bc']), [(start: 0, end: 3)]);
      expect(matchRanges('abcd', ['ab', 'cd']), [(start: 0, end: 4)]);
      expect(matchRanges('ABC', ['b']), [(start: 1, end: 2)]);
      expect(matchRanges('なし', ['毛玉']), isEmpty);
    });

    test('UT-SR-05 境界値：最初に当たった位置が10文字以内なら先頭から、11文字目より後ならその10文字前から出す', () {
      expect(snippetStart([]), 0);
      expect(snippetStart([(start: 10, end: 12)]), 0);
      expect(snippetStart([(start: 11, end: 13)]), 1);
      expect(snippetStart([(start: 50, end: 52)]), 40);
    });
  });

  late AppDatabase db;
  late RecordRepository repo;
  late DateTime now;
  late Map<String, String> typeIds;

  setUp(() async {
    db = memoryDatabase();
    now = _now;
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'ソラ',
      status: 'farewell',
    );
    await repo.addStandardTypes('h1');
    typeIds = {
      for (final t in await db.select(db.recordTypes).get()) t.kind: t.id,
    };
    _FakeSync.calls = 0;
  });

  tearDown(() => db.close());

  /// 記録を1件作る（日時とメモを付ける）
  Future<String> add(
    String catId,
    String kind,
    DateTime at, {
    String? memo,
  }) async {
    final id = await repo.addRecord(
      catId: catId,
      recordTypeId: typeIds[kind]!,
      author: _author,
      recordedAt: at,
    );
    if (memo != null) {
      await repo.updateRecord(
        id: id,
        recordedAt: at,
        level: null,
        valueNumber: null,
        memo: memo,
        author: _author,
      );
    }
    return id;
  }

  Future<List<String>> search(SearchQuery query) async => [
    for (final e in await repo.watchSearch('h1', query).first) e.id,
  ];

  group('端末の記録から探す（リポジトリ）', () {
    late String a;
    late String b;
    late String c;
    late String d;

    setUp(() async {
      a = await add('c1', 'vomit', DateTime(2026, 11, 2, 12), memo: '毛玉を吐いた');
      b = await add('c1', 'food', DateTime(2026, 11, 3, 8), memo: '毛玉が混ざる');
      c = await add('c2', 'vomit', DateTime(2026, 10, 1, 9), memo: '透明な液');
      d = await add('c1', 'water', DateTime(2026, 11, 19, 7));
    });

    test('UT-SR-06 条件がなければ、すべてを新しい順に出す（お別れの猫の記録も）', () async {
      expect(await search(emptyQuery), [d, b, a, c]);
    });

    test('UT-SR-07 メモの言葉で絞る。複数の言葉はすべてを含むものだけ', () async {
      expect(await search(q(words: '毛玉')), [b, a]);
      expect(await search(q(words: '毛玉 吐いた')), [a]);
      expect(await search(q(words: 'ない言葉')), isEmpty);
    });

    test('UT-SR-08 項目・猫で絞る（お別れの猫も選べる）', () async {
      expect(await search(q(typeId: typeIds['vomit'])), [a, c]);
      expect(await search(q(catId: 'c2')), [c]);
      expect(await search(q(typeId: typeIds['vomit'], catId: 'c1')), [a]);
    });

    test('UT-SR-09 境界値：期間は両端の日を含み、片方だけでも絞れる', () async {
      expect(
        await search(q(from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 3))),
        [b, a],
      );
      expect(await search(q(from: DateTime(2026, 11, 3))), [d, b]);
      expect(await search(q(to: DateTime(2026, 11, 1))), [c]);
    });

    test('UT-SR-10 削除した記録と、ほかのおうちの記録は出さない', () async {
      await repo.deleteRecord(id: b, author: _author);
      await addHousehold(db, 'h2');
      await addCat(db, id: 'x1', householdId: 'h2', name: 'よそ');
      await repo.addRecord(
        catId: 'x1',
        recordTypeId: typeIds['food']!,
        author: _author,
      );
      expect(await search(q(words: '毛玉')), [a]);
      expect(await search(emptyQuery), [d, a, c]);
    });
  });

  Future<void> show(
    WidgetTester tester,
    String location, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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
          path: '/search',
          builder: (context, state) => const SearchScreen(),
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
          nowProvider.overrideWithValue(() => _now),
          syncControllerProvider.overrideWith(_FakeSync.new),
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

  group('記録の検索（S-23）', () {
    testWidgets('UT-SR-11 カレンダーの虫めがねで開き、開いたとき1回だけ同期する', (tester) async {
      await show(tester, '/calendar');

      await tester.tap(find.byTooltip('記録の検索'));
      await tester.pumpAndSettle();
      expect(find.text('記録の検索'), findsWidgets);
      expect(_FakeSync.calls, 1);

      // 言葉を入れても、同期し直さない
      await tester.enterText(find.byType(TextField), '毛玉');
      await tester.pumpAndSettle();
      expect(_FakeSync.calls, 1);
      await close(tester);
    });

    testWidgets('UT-SR-12 言葉を入れると、当たった記録を新しい順に出す。押すと詳細へ進む', (tester) async {
      final a = await add(
        'c1',
        'vomit',
        DateTime(2026, 11, 2, 12),
        memo: '毛玉を吐いた',
      );
      await add('c1', 'food', DateTime(2026, 11, 3, 8), memo: '毛玉が混ざる');
      await add('c1', 'water', DateTime(2026, 11, 4, 8), memo: '少なめ');
      await show(tester, '/search');

      await tester.enterText(find.byType(TextField), '吐いた');
      await tester.pumpAndSettle();
      expect(find.text('11/02 12:00'), findsOneWidget);
      expect(find.text('11/03 08:00'), findsNothing);

      await tester.enterText(find.byType(TextField), '毛玉');
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('11/03 08:00')).dy;
      final second = tester.getTopLeft(find.text('11/02 12:00')).dy;
      expect(first, lessThan(second));

      await tester.tap(find.text('11/02 12:00'));
      await tester.pumpAndSettle();
      expect(find.text('詳細：$a'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-SR-13 当たった言葉に色を付ける', (tester) async {
      await add('c1', 'vomit', DateTime(2026, 11, 2, 12), memo: '毛玉を吐いた');
      await show(tester, '/search');

      await tester.enterText(find.byType(TextField), '毛玉');
      await tester.pumpAndSettle();
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'メモ：毛玉を吐いた',
          ),
        ),
      );
      final colored = <String>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor != null) {
          colored.add(span.text!);
        }
        return true;
      });
      expect(colored, ['毛玉']);
      await close(tester);
    });

    testWidgets('UT-SR-14 当たる記録がなければ「見つかりませんでした」', (tester) async {
      await add('c1', 'food', DateTime(2026, 11, 2, 8), memo: 'ふつう');
      await show(tester, '/search');
      expect(find.text('11/02 08:00'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ない言葉');
      await tester.pumpAndSettle();
      expect(find.text('見つかりませんでした'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-SR-15 項目で絞り込める。非表示の項目も選べる', (tester) async {
      await add('c1', 'food', DateTime(2026, 11, 2, 8));
      await add('c1', 'water', DateTime(2026, 11, 3, 8));
      final hidden = await repo.addCustomType(
        householdId: 'h1',
        userId: 'u1',
        name: '爪切り',
        icon: 'custom_nail',
      );
      await repo.addRecord(
        catId: 'c1',
        recordTypeId: hidden,
        author: _author,
        recordedAt: DateTime(2026, 11, 4, 8),
      );
      await repo.setTypeHidden(id: hidden, userId: 'u1', hidden: true);
      await show(tester, '/search');

      await tester.tap(find.text('すべての項目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('水').last);
      await tester.pumpAndSettle();
      expect(find.text('11/03 08:00'), findsOneWidget);
      expect(find.text('11/02 08:00'), findsNothing);

      await tester.tap(find.text('水'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('爪切り（非表示中）').last);
      await tester.pumpAndSettle();
      expect(find.text('11/04 08:00'), findsOneWidget);
      expect(find.text('11/03 08:00'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-SR-16 期間を選んで絞り込み、「期間を外す」で戻す', (tester) async {
      await add('c1', 'food', DateTime(2026, 11, 2, 8));
      await add('c1', 'food', DateTime(2026, 11, 18, 8));
      await show(tester, '/search');
      expect(find.byTooltip('期間を外す'), findsNothing);

      await tester.tap(find.text('始め'));
      await tester.pumpAndSettle();
      // 日付の選択は今日（11/19）を開く。10日を選んで OK
      await tester.tap(find.text('10'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2026/11/10'), findsOneWidget);
      expect(find.text('11/18 08:00'), findsOneWidget);
      expect(find.text('11/02 08:00'), findsNothing);

      await tester.tap(find.byTooltip('期間を外す'));
      await tester.pumpAndSettle();
      expect(find.text('11/02 08:00'), findsOneWidget);
      await close(tester);
    });
  });

  testWidgets('UT-SR-18 項目と猫の絞り込みは左に寄せる（S-23 の絵。#272）', (tester) async {
    await show(tester, '/search');

    expect(tester.getTopLeft(find.text('すべての項目')).dx, lessThan(40));
    await close(tester);
  });

  testWidgets(
    'UT-SR-19 広い窓（1280px）では、言葉の欄と結果の幅を 640px までにして中央に寄せる。狭い画面では左右 12 の余白（NF-UX-02。#274）',
    (tester) async {
      await add('c1', 'food', DateTime(2026, 11, 2, 8), memo: 'ふつう');
      await show(tester, '/search', width: 1280);

      final field = tester.getRect(find.byType(TextField));
      expect(field.width, lessThanOrEqualTo(640));
      expect(field.left, closeTo((1280 - 640) / 2, 1));
      expect(tester.getTopLeft(find.text('すべての項目')).dx, closeTo(320, 1));
      final row = tester.getRect(find.byType(ListTile));
      expect(row.left, greaterThanOrEqualTo(300));
      expect(row.right, lessThanOrEqualTo(980));
      await close(tester);

      await show(tester, '/search');
      expect(tester.getRect(find.byType(TextField)).left, closeTo(12, 1));
      await close(tester);
    },
  );

  test('UT-SR-17 アプリの道筋に、記録の検索（/search）がある', () {
    final router = createRouter();
    addTearDown(router.dispose);
    expect(
      router.configuration.findMatch(Uri.parse('/search')).isNotEmpty,
      isTrue,
    );
  });
}
