import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meowscope/features/export/presentation/csv_export_screen.dart';

import 'helpers/e2e_app.dart';
import 'helpers/flows.dart';
import 'helpers/server_api.dart';

/// Ver.1.4.0 の E2E テスト（NF-MT-02）。本物のサーバーにつなぎ、1.4.0 の主要な操作を画面から行う
///
/// 動かし方は tool/e2e.dart（テスト仕様書 6章）。CSV の出力とくわしい統計は Windows だけ
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final windows = defaultTargetPlatform == TargetPlatform.windows;

  /// 設定のおうちの管理（S-42）を開く
  Future<void> openHousehold(WidgetTester tester) async {
    await tapText(tester, '設定');
    await tapText(tester, 'おうちの管理');
  }

  testWidgets(
    'E2E-11 2つ目のおうち：S-42 から作ると今のおうちになり、切り替えるとそのおうちの猫が出る。サーバーにも両方のおうちが届く（F-SH-09）',
    (tester) async {
      final app = E2eApp();
      await app.start(tester);
      await register(tester, ServerApi.uniqueEmail('twohomes'), 'はる');
      await createHouseholdAndCat(tester);

      await openHousehold(tester);
      await tester.ensureVisible(find.text('新しいおうちを作る'));
      await tapText(tester, '新しいおうちを作る');
      await enter(tester, 'おうちの名前', 'たま家');
      await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
      await waitFor(tester, find.widgetWithText(TextFormField, '名前'));
      await enter(tester, '名前', 'タマ');
      await tester.tap(find.widgetWithText(FilledButton, '登録する'));
      // 登録の後は、開いていたタブ（設定）に戻る。ホームを開いて、今のおうちが新しいおうちか確かめる
      await waitFor(tester, find.text('おうちの管理'));
      await tapText(tester, 'ホーム');
      await waitFor(tester, find.widgetWithText(AppBar, 'たま家'));

      // 2つ目のおうちも送り、サーバーから両方のおうちのメンバーとして届く
      await syncNow(tester);
      final members = await eventually(
        () => app.db.select(app.db.householdMembers).get(),
        (rows) => rows.length >= 2,
      );
      expect(members.map((m) => m.householdId).toSet(), hasLength(2));

      // 最初のおうちに切り替えると、そのおうちの猫が出る
      await openHousehold(tester);
      expect(find.text('おうちを切り替える'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'E2E家'));
      await waitFor(tester, find.text('E2E家に切り替えました'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapText(tester, 'ホーム');
      await waitFor(tester, find.widgetWithText(AppBar, 'E2E家'));
      await app.close(tester);
    },
  );

  testWidgets(
    'E2E-12 CSV の出力（Windows）：全期間・すべてで保存すると、BOM つきの UTF-8 で、今のおうちの記録が1行1件で入る（F-EX-01）',
    (tester) async {
      final dir = await Directory.systemTemp.createTemp('meowscope_e2e_csv_');
      final path = '${dir.path}${Platform.pathSeparator}e2e.csv';
      final app = E2eApp();
      // 保存の画面（OS の画面）は操作できないので、選んだ場所を返す版に差し替える（テストの側の差し替え）
      await app.start(
        tester,
        overrides: [
          csvSaveLocationProvider.overrideWithValue((name) async => path),
        ],
      );
      await register(tester, ServerApi.uniqueEmail('csv'), 'はる');
      await createHouseholdAndCat(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await tester.pumpAndSettle();

      await tapText(tester, '設定');
      await tester.scrollUntilVisible(find.text('CSV の出力'), 100);
      await tapText(tester, 'CSV の出力');
      await tester.tap(find.widgetWithText(FilledButton, 'CSV を出力'));
      await waitFor(tester, find.text('CSV を保存しました（1件）'));

      final bytes = await File(path).readAsBytes();
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final lines = utf8.decode(bytes.sublist(3)).trimRight().split('\r\n');
      expect(lines, hasLength(2));
      expect(lines[1], contains(',ミケ,ご飯,'));
      await app.close(tester);
      await dir.delete(recursive: true);
    },
    skip: !windows,
  );

  testWidgets(
    'E2E-13 くわしい統計（Windows）：統計の「くわしく見る」から開き、記録した猫と項目の線・時間帯の傾向・日ごとの表が出る（F-ST-04〜08）',
    (tester) async {
      final app = E2eApp();
      await app.start(tester);
      await register(tester, ServerApi.uniqueEmail('detail'), 'はる');
      await createHouseholdAndCat(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await tester.pumpAndSettle();

      await tapText(tester, '統計');
      await tapText(tester, 'くわしく見る');
      await waitFor(tester, find.text('ミケ・ご飯（回・左）'));
      expect(find.text('時間帯の傾向'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('日ごとの表'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ミケ・ご飯（回）'), findsOneWidget);
      await app.close(tester);
    },
    skip: !windows,
  );
}
