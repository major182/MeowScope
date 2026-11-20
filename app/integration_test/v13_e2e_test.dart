import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e_app.dart';
import 'helpers/flows.dart';
import 'helpers/server_api.dart';

/// Ver.1.3.0 の E2E テスト（NF-MT-02）。本物のサーバーにつなぎ、1.3.0 の主要な操作を画面から行う
///
/// 動かし方は tool/e2e.dart（テスト仕様書 6章）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final api = ServerApi();

  /// カレンダーの日のセル
  Finder dayCell(DateTime d) => find.byKey(ValueKey('day-${d.month}-${d.day}'));

  /// 今日（0時0分）
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// カレンダーを開き、[day] のある月を出す（前の日が前の月で、今月の表に出ないことがあるため）
  Future<void> openCalendarAt(WidgetTester tester, DateTime day) async {
    await tapText(tester, 'カレンダー');
    if (dayCell(day).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('前の月'));
      await tester.pumpAndSettle();
    }
  }

  /// 日別一覧（狭い幅で開く画面）などが重なっていれば閉じて、カレンダーに戻る
  Future<void> backToCalendar(WidgetTester tester) async {
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'E2E-06 カレンダーの日付から記録：前の日を長押しして記録すると、その日の日時で保存され、その日のセルに印が出る（F-VW-06）',
    (tester) async {
      final app = E2eApp();
      await app.start(tester);
      await register(tester, ServerApi.uniqueEmail('fromdate'), 'はる');
      await createHouseholdAndCat(tester);

      final t = today();
      final yesterday = DateTime(t.year, t.month, t.day - 1);
      await openCalendarAt(tester, yesterday);
      await tester.longPress(dayCell(yesterday));
      await waitFor(tester, find.text('項目を選んでください'));
      // 猫が1匹なので選ばずに、③の詳細入力へ進む
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await waitFor(tester, find.widgetWithText(TextButton, '保存'));
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      // 保存すると、その日の日別一覧を出す（狭い幅は日別一覧の画面、広い幅はカレンダーの右）
      await waitFor(tester, find.text('ミケ　ご飯'));

      final record = await app.db.select(app.db.records).getSingle();
      final at = record.recordedAt.toLocal();
      expect(DateTime(at.year, at.month, at.day), yesterday);

      await backToCalendar(tester);
      expect(
        find.descendant(
          of: dayCell(yesterday),
          matching: find.image(const AssetImage('assets/icons/cal_food.png')),
        ),
        findsOneWidget,
      );
      await app.close(tester);
    },
  );

  testWidgets('E2E-07 記録の検索：メモの言葉で探すと当たった記録だけが出て、押すと詳細が開く（F-VW-03）', (
    tester,
  ) async {
    final app = E2eApp();
    await app.start(tester);
    await register(tester, ServerApi.uniqueEmail('search'), 'はる');
    await createHouseholdAndCat(tester);

    // メモ付きの記録と、メモのない記録を作る
    await tester.tap(find.widgetWithText(OutlinedButton, '吐いた'));
    await waitFor(tester, find.text('ミケ　吐いた'));
    await tapText(tester, 'ミケ　吐いた');
    await tapText(tester, '編集');
    await enter(tester, 'メモ', '毛玉のようなもの');
    await tapText(tester, '保存');
    await waitFor(tester, find.text('毛玉のようなもの'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '水'));
    await waitFor(tester, find.text('ミケ　水'));

    await tapText(tester, 'カレンダー');
    await tester.tap(find.byTooltip('記録の検索'));
    await waitFor(tester, find.text('メモの言葉'));
    await tester.enterText(find.byType(TextField).first, '毛玉');
    await waitFor(tester, find.textContaining('毛玉', findRichText: true));
    expect(find.text('ミケ　吐いた'), findsOneWidget);
    expect(find.text('ミケ　水'), findsNothing);

    await tester.tap(find.text('ミケ　吐いた'));
    await waitFor(tester, find.text('記録の詳細'));
    expect(find.text('毛玉のようなもの'), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('E2E-08 記録項目の並べ替え：設定でつまみを動かすとホームの並びが変わり、アプリを開き直しても残る（F-RC-07）', (
    tester,
  ) async {
    final app = E2eApp();
    await app.start(tester);
    await register(tester, ServerApi.uniqueEmail('order'), 'はる');
    await createHouseholdAndCat(tester);

    await tapText(tester, '設定');
    await tapText(tester, '記録項目の設定');
    // 病院（一番下）のつまみを、ご飯（一番上）より上まで、指で少しずつ動かす
    final from = tester.getCenter(find.byTooltip('病院を動かす'));
    final to = tester.getCenter(find.byTooltip('ご飯を動かす'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 100));
    const steps = 20;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(
        Offset(from.dx, from.dy + (to.dy - 40 - from.dy) * i / steps),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('病院（標準）')).dy,
      lessThan(tester.getTopLeft(find.text('ご飯（標準）')).dy),
    );

    /// ホームで病院がご飯より前（上、同じ段なら左）にあるか
    bool vetFirst() {
      final vet = tester.getTopLeft(find.widgetWithText(OutlinedButton, '病院'));
      final food = tester.getTopLeft(find.widgetWithText(OutlinedButton, 'ご飯'));
      return vet.dy < food.dy || (vet.dy == food.dy && vet.dx < food.dx);
    }

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapText(tester, 'ホーム');
    expect(vetFirst(), isTrue);

    // 開き直しても残る（並び順は端末に置く。BR-36）
    await app.restart(tester);
    await waitFor(tester, find.widgetWithText(OutlinedButton, '病院'));
    expect(vetFirst(), isTrue);
    await app.close(tester);
  });

  testWidgets(
    'E2E-09 病院：名前と次の予定日を入れると、カレンダーに予定の印、プロフィールに病院の履歴が出て、サーバーに届く（F-MD-01）',
    (tester) async {
      final app = E2eApp();
      final email = ServerApi.uniqueEmail('vet');
      await app.start(tester);
      await register(tester, email, 'はる');
      await createHouseholdAndCat(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, '病院'));
      await waitFor(tester, find.text('詳細を追加'));
      await tapText(tester, '詳細を追加');
      await waitFor(tester, find.text('次の予定日'));
      await enter(tester, '病院の名前', 'みどり動物病院');
      // 次の予定日：日付の選択は今日を開くので、そのまま OK（今日は選べる）
      await tapText(tester, '選ぶ');
      await tapText(tester, 'OK');
      await tapText(tester, '保存');
      await waitFor(tester, find.text('ミケ　病院'));

      // カレンダー：今日のセルに、病院の記録の印と予定の印の2つ（どちらも通院のイラスト）
      final t = today();
      await tapText(tester, 'カレンダー');
      expect(
        find.descendant(
          of: dayCell(t),
          matching: find.image(const AssetImage('assets/icons/custom_vet.png')),
        ),
        findsNWidgets(2),
      );

      // 猫のプロフィールの病院の履歴
      await tapText(tester, '設定');
      await tapText(tester, '猫の一覧とプロフィール');
      await tapText(tester, 'ミケ');
      await tester.scrollUntilVisible(
        find.text('みどり動物病院'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('病院の履歴'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // サーバーに名前と予定日が届く
      await syncNow(tester);
      final changes = await api.sync(await api.login(email, e2ePassword));
      final vetType = changes.firstWhere(
        (c) =>
            c['table'] == 'record_types' && (c['data'] as Map)['kind'] == 'vet',
      );
      final record = changes.firstWhere(
        (c) =>
            c['table'] == 'records' &&
            (c['data'] as Map)['recordTypeId'] == vetType['id'],
      );
      final detail = (record['data'] as Map)['detail'] as Map;
      expect(detail['hospital'], 'みどり動物病院');
      String two(int n) => n.toString().padLeft(2, '0');
      expect(detail['nextDate'], '${t.year}-${two(t.month)}-${two(t.day)}');
      await app.close(tester);
    },
  );

  testWidgets(
    'E2E-10 古い版で作ったおうち：サーバーが足した病院が届き、まとめた「通院」への記録は病院の記録として出る（BR-37・38）',
    (tester) async {
      // 古い版のアプリの操作をサーバーの API で行う：病院なしでおうちを作り、通院の独自の項目を作る
      final email = ServerApi.uniqueEmail('oldapp');
      final token = await api.register(email, e2ePassword, 'なつ');
      final ids = await api.createHousehold(token, 'なつ家');
      final cat = await api.addCatAndRecord(
        token,
        household: ids.household,
        catName: 'タマ',
        typeId: ids.food,
        authorName: 'なつ',
      );
      final visit = await api.addCustomType(
        token,
        household: ids.household,
        name: '通院',
        icon: 'custom_vet',
      );
      // V10 でまとめた後の状態（通院の項目に削除の印）にしてから、古い端末が通院へ記録を送る
      await api.deleteCustomType(
        token,
        id: visit,
        household: ids.household,
        name: '通院',
        icon: 'custom_vet',
      );
      await api.addRecord(token, catId: cat, typeId: visit, authorName: 'なつ');

      // 新しい版のアプリでログインする
      final app = E2eApp();
      await app.start(tester);
      await enter(tester, 'メールアドレス', email);
      await enter(tester, 'パスワード', e2ePassword);
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await waitFor(tester, find.text('タマ　病院'));

      // ホームに病院（サーバーが足した1つだけ）が出て、通院は出ない
      expect(find.widgetWithText(OutlinedButton, '病院'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '通院'), findsNothing);
      final vets = await (app.db.select(
        app.db.recordTypes,
      )..where((t) => t.kind.equals('vet'))).get();
      expect(vets, hasLength(1));
      await app.close(tester);
    },
  );
}
