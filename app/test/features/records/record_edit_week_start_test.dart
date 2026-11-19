import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/presentation/record_edit_screen.dart';
import 'package:meowscope/features/settings/data/settings_repository.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');

/// 品質チェック A-1（#270）：記録の詳細入力（S-12）の日付の選択が、週の始まりの設定を使う（F-VW-04）
void main() {
  late AppDatabase db;
  late String id;

  setUp(() async {
    db = memoryDatabase();
    final repo = RecordRepository(db);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await repo.addStandardTypes('h1');
    final food = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals('food'))).getSingle();
    id = await repo.addRecord(
      catId: 'c1',
      recordTypeId: food.id,
      author: _author,
    );
  });

  tearDown(() => db.close());

  Future<void> openDatePicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => RecordEditScreen(recordId: id),
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
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ja', 'JP'),
          supportedLocales: const [Locale('ja', 'JP')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 日時のボタン（記録の日時を出している）を押す
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('UT-RS-20 日時の選択は、アプリの週の始まり（月曜）で並ぶ', (tester) async {
    await SettingsRepository(db).setWeekStart(WeekStart.monday);
    await openDatePicker(tester);

    // 曜日の見出しの「月」が「日」より左にある
    final mon = tester.getCenter(find.text('月').first).dx;
    final sun = tester.getCenter(find.text('日').first).dx;
    expect(mon, lessThan(sun));
    await close(tester);
  });

  testWidgets('UT-RS-21 週の始まりが日曜なら、日曜から並ぶ', (tester) async {
    await SettingsRepository(db).setWeekStart(WeekStart.sunday);
    await openDatePicker(tester);

    final mon = tester.getCenter(find.text('月').first).dx;
    final sun = tester.getCenter(find.text('日').first).dx;
    expect(sun, lessThan(mon));
    await close(tester);
  });
}
