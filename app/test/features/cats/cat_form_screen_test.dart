import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/core/widgets/save_guard.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/cats/data/cat_repository.dart';
import 'package:meowscope/features/cats/presentation/cat_form_screen.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

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
  });

  tearDown(() => db.close());

  /// 猫の登録画面を、ホームの目印の上に開く
  Future<void> show(
    WidgetTester tester, {
    List extra = const [],
    // アプリと同じ日本語で開くとき（日付の選択の週の始まりを確かめる）
    bool japanese = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/cats/new',
      routes: [
        // 登録後のメッセージを出せるよう、ホームの目印も Scaffold に置く
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('ホームの目印')),
        ),
        GoRoute(
          path: '/cats/new',
          builder: (context, state) =>
              CatFormScreen(today: DateTime(2026, 11, 3)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          ...extra.cast(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: japanese ? const Locale('ja', 'JP') : null,
          supportedLocales: const [Locale('en', 'US'), Locale('ja', 'JP')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// 「登録する」は画面の下にあるので、見える位置まで送ってから押す
  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '登録する');
    // 入力欄も中にスクロールを持つので、画面全体のリストを指定する
    await tester.scrollUntilVisible(
      button,
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('UT-CT-06 名前が空欄なら登録しない', (tester) async {
    await show(tester);

    await submit(tester);

    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(await db.select(db.cats).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-CT-07 名前が空白だけなら登録しない', (tester) async {
    await show(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '   ');
    await submit(tester);

    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(await db.select(db.cats).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-CT-08 名前だけで登録し、ホームへ戻る', (tester) async {
    await show(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケ');
    await submit(tester);

    expect(find.text('ホームの目印'), findsOneWidget);
    expect(find.text('ミケを登録しました'), findsOneWidget);
    final cat = await db.select(db.cats).getSingle();
    expect(cat.name, 'ミケ');
    expect(cat.householdId, 'h1');
    await close(tester);
  });

  testWidgets('UT-CT-09 生年月日・性別・持病を入力して登録する', (tester) async {
    await show(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'タマ');
    await tester.tap(find.byTooltip('生年月日を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('2026/11/3'), findsOneWidget);
    await tester.tap(find.text('女の子'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '持病'), '腎臓');
    await submit(tester);

    final cat = await db.select(db.cats).getSingle();
    expect(cat.birthDate!.toUtc(), DateTime.utc(2026, 11, 3));
    expect(cat.sex, 'female');
    expect(cat.conditions, '腎臓');
    await close(tester);
  });

  testWidgets('UT-CT-10 選んだ生年月日と性別を取り消せる', (tester) async {
    await show(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケ');
    await tester.tap(find.byTooltip('生年月日を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('生年月日を消す'));
    await tester.pumpAndSettle();
    expect(find.text('未設定'), findsOneWidget);
    final segments = find.byType(SegmentedButton<CatSex>);
    expect(
      find.descendant(of: segments, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    await tester.tap(find.text('男の子'));
    await tester.pumpAndSettle();
    // 選んだ性別には ✓ を出す（ほかの選択と同じ見た目にそろえる）
    expect(
      find.descendant(of: segments, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await tester.tap(find.text('男の子'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: segments, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    await submit(tester);

    final cat = await db.select(db.cats).getSingle();
    expect(cat.birthDate, isNull);
    expect(cat.sex, isNull);
    await close(tester);
  });

  testWidgets('UT-CT-11 生年月日の選択を閉じたら未設定のまま', (tester) async {
    await show(tester);

    await tester.tap(find.byTooltip('生年月日を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('未設定'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-CT-12 未来の日付は選べない', (tester) async {
    await show(tester);

    await tester.tap(find.byTooltip('生年月日を選ぶ'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.lastDate, DateTime(2026, 11, 3));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await close(tester);
  });

  testWidgets('UT-CT-13 保存に失敗したら案内を出して画面に残り、もう一度押せる', (tester) async {
    await show(
      tester,
      extra: [
        catRepositoryProvider.overrideWithValue(_FailingCatRepository(db)),
      ],
    );

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケ');
    await submit(tester);

    expect(find.text(saveFailedMessage), findsOneWidget);
    expect(find.text('ホームの目印'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '登録する'),
    );
    expect(button.onPressed, isNotNull);
    await close(tester);
  });

  testWidgets('UT-CT-14 生年月日の選択は、アプリの週の始まり（月曜）で並ぶ', (tester) async {
    await SettingsRepository(db).setWeekStart(WeekStart.monday);
    await show(tester, japanese: true);

    await tester.tap(find.byTooltip('生年月日を選ぶ'));
    await tester.pumpAndSettle();
    // 曜日の見出しの「月」が「日」より左にある
    final mon = tester.getCenter(find.text('月').first).dx;
    final sun = tester.getCenter(find.text('日').first).dx;
    expect(mon, lessThan(sun));
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await close(tester);
  });
}

/// 猫の保存に失敗する（テストの側の差し替え）
class _FailingCatRepository extends CatRepository {
  _FailingCatRepository(super.db);

  @override
  Future<String> addCat({
    required String householdId,
    required String userId,
    required String name,
    DateTime? birthDate,
    CatSex? sex,
    String? conditions,
  }) async => throw StateError('保存できない');
}
