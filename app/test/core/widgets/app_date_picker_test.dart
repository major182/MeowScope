import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/widgets/app_date_picker.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';

void main() {
  /// ボタンを押すと日付の選択を開く画面。アプリと同じ日本語の設定にする
  Future<void> open(
    WidgetTester tester,
    WeekStart weekStart, {
    Locale locale = const Locale('ja', 'JP'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDatePicker(
              context: context,
              weekStart: weekStart,
              // 2024年1月：1日が月曜の月
              initialDate: DateTime(2024, 1, 19),
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
            ),
            child: const Text('開く'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
  }

  /// 曜日の見出しで、[a] が [b] より左にあるか
  bool isLeftOf(WidgetTester tester, String a, String b) =>
      tester.getCenter(find.text(a).first).dx <
      tester.getCenter(find.text(b).first).dx;

  testWidgets('UT-DP-01 週の始まりが月曜なら、月曜から並ぶ', (tester) async {
    await open(tester, WeekStart.monday);
    expect(isLeftOf(tester, '月', '日'), isTrue);
    // 見出し以外の日本語の表示は変わらない
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('1月19日(金)'), findsOneWidget);
  });

  testWidgets('UT-DP-02 週の始まりが日曜なら、日曜から並ぶ', (tester) async {
    await open(tester, WeekStart.sunday);
    expect(isLeftOf(tester, '日', '月'), isTrue);
    expect(find.text('キャンセル'), findsOneWidget);
  });

  testWidgets('UT-DP-03 日本語以外の言語では差し替えず、その言語の決まりのまま', (tester) async {
    await open(tester, WeekStart.monday, locale: const Locale('en', 'US'));
    // 英語（米国）の決まりは日曜始まり。見出しは S M T W T F S
    expect(find.text('Cancel'), findsOneWidget);
    expect(isLeftOf(tester, 'S', 'M'), isTrue);
  });
}
