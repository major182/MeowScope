import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/medication/data/medication_repository.dart';
import 'package:meowscope/features/medication/presentation/medication_form_screen.dart';
import 'package:meowscope/features/medication/presentation/medication_schedules_screen.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/features/notifications/domain/reminder_plan.dart';
import 'package:meowscope/features/notifications/presentation/notification_runner.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

const _session = Session(
  author: Author(id: 'u1', name: 'はる'),
  householdId: 'h1',
);

void main() {
  late AppDatabase db;
  late MedicationRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = MedicationRepository(db);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'タマ',
      createdAt: testTime.add(const Duration(days: 1)),
    );
  });
  tearDown(() => db.close());

  Future<String> add(
    String catId, {
    String name = '○○錠',
    String? dose = '1錠',
    String time = '08:00',
  }) => repo.add(
    householdId: 'h1',
    userId: 'u1',
    catId: catId,
    name: name,
    dose: dose,
    timeOfDay: time,
  );

  Future<void> show(WidgetTester tester, {String path = '/medications'}) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/medications',
          builder: (context, state) => const MedicationSchedulesScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const MedicationFormScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  MedicationFormScreen(scheduleId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
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

  /// 削除していない予定を1つ読む（画面のテストの中では、見張りではなく一度だけ読む）
  Future<MedicationScheduleRow?> live(String id) => (db.select(
    db.medicationSchedules,
  )..where((m) => m.id.equals(id) & m.deletedAt.isNull())).getSingleOrNull();

  Future<List<MedicationScheduleRow>> rows() =>
      db.select(db.medicationSchedules).get();

  testWidgets('UT-MD-11 S-50：予定がなければ案内を出す', (tester) async {
    await show(tester);
    expect(find.text('お薬の予定はまだありません'), findsOneWidget);
    expect(find.text('予定を追加'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-MD-12 S-50：猫ごとに時刻の順で並べ、量がなければ薬の名前だけ。お別れの猫は印を付ける', (
    tester,
  ) async {
    await add('c1', time: '20:00');
    await add('c1', time: '08:00');
    await add('c2', name: '目薬', dose: null, time: '09:00');
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(status: Value('farewell')),
    );
    await show(tester);

    expect(find.text('ミケ'), findsOneWidget);
    expect(find.text('タマ（お別れ）'), findsOneWidget);
    expect(find.text('○○錠 1錠'), findsNWidgets(2));
    expect(find.text('目薬'), findsOneWidget);
    final times = [
      for (final t in tester.widgetList<Text>(
        find.textContaining(RegExp(r'^\d\d:\d\d$')),
      ))
        t.data,
    ];
    expect(times, ['08:00', '20:00', '09:00']);
    await close(tester);
  });

  testWidgets('UT-MD-13 S-50：スイッチでオン・オフをすぐ保存する', (tester) async {
    await add('c1');
    await show(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect((await rows()).single.enabled, isFalse);
    await close(tester);
  });

  testWidgets('UT-MD-14 追加：猫が1匹でなければ選ばせ、名前は必須。境界値：20文字は保存でき、21文字は保存しない', (
    tester,
  ) async {
    await show(tester, path: '/medications/new');

    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();
    expect(find.text(medicationCatRequired), findsOneWidget);
    expect(find.text(medicationNameRequired), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('タマ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '薬の名前'),
      'あ' * 21,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '量（任意。例：1錠）'),
      'い' * 21,
    );
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();
    expect(find.text(medicationTooLong), findsNWidgets(2));
    expect(await rows(), isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, '薬の名前'),
      'あ' * 20,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '量（任意。例：1錠）'),
      'い' * 20,
    );
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    final saved = (await rows()).single;
    expect(saved.catId, 'c2');
    expect(saved.name, 'あ' * 20);
    expect(saved.dose, 'い' * 20);
    // 時刻を選ばなければ 08:00
    expect(saved.timeOfDay, '08:00');
    expect(find.text('お薬の予定を保存しました'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-MD-15 追加：猫が1匹なら選んだ状態で開く。時刻を選んで保存する', (tester) async {
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(status: Value('farewell')),
    );
    await show(tester, path: '/medications/new');
    // お別れの猫は選べない
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('タマ'), findsNothing);
    expect(find.text('タマ（お別れ）'), findsNothing);
    await tester.tap(find.text('ミケ').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '薬の名前'), '目薬');
    await tester.tap(find.byTooltip('時刻を選ぶ'));
    await tester.pumpAndSettle();
    // 時刻の選択を文字の入力に切り替えて、21:05 を入れる
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '9');
    await tester.enterText(fields.at(1), '05');
    await tester.tap(find.text('PM'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('21:05'), findsOneWidget);

    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    final saved = (await rows()).single;
    expect(saved.catId, 'c1');
    expect(saved.dose, isNull);
    expect(saved.timeOfDay, '21:05');
    await close(tester);
  });

  testWidgets('UT-MD-16 編集：一覧から開いて変え、通知をオフにして保存する。お別れの猫の予定も、その猫のまま開ける', (
    tester,
  ) async {
    final id = await add('c2');
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(status: Value('farewell')),
    );
    await show(tester);
    await tester.tap(find.text('○○錠 1錠'));
    await tester.pumpAndSettle();

    expect(find.text('予定の編集'), findsOneWidget);
    expect(find.text('タマ（お別れ）'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '量（任意。例：1錠）'),
      '2錠',
    );
    await tester.tap(find.text('通知する'));
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    final row = await live(id);
    expect(row!.dose, '2錠');
    expect(row.enabled, isFalse);
    expect(row.catId, 'c2');
    expect(find.text('お薬の予定'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-MD-17 削除：確認でキャンセルなら残し、削除なら消して一覧へ戻る', (tester) async {
    final id = await add('c1');
    await show(tester, path: '/medications/$id');

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await live(id), isNotNull);

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(await live(id), isNull);
    await close(tester);
  });

  testWidgets('UT-MD-18 削除済みの予定を開くと案内を出す。猫がいなければ追加できない', (tester) async {
    final id = await add('c1');
    await repo.delete(id: id, userId: 'u1');
    await show(tester, path: '/medications/$id');
    expect(find.text('この予定は削除されました'), findsOneWidget);
    await close(tester);

    for (final c in ['c1', 'c2']) {
      await (db.update(db.cats)..where((x) => x.id.equals(c))).write(
        const CatsCompanion(status: Value('farewell')),
      );
    }
    await show(tester, path: '/medications/new');
    expect(find.text('予定を追加できる猫がいません。先に猫を登録してください'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存する'),
    );
    expect(button.onPressed, isNull);
    await close(tester);
  });

  test('UT-MD-19 予約の計算（結合：予定→予約）：オンの予定だけ、お別れ・削除した猫の予定は予約しない', () async {
    await add('c1');
    final off = await add('c1', time: '09:00');
    await repo.setEnabled(id: off, userId: 'u1', enabled: false);
    await add('c2', time: '10:00');
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(status: Value('farewell')),
    );
    final notifier = RecordingNotifier();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWith((ref) => Stream.value(_session)),
        notifierProvider.overrideWithValue(notifier),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(medicationPlanProvider, (_, _) {});
    List<PlannedNotification>? plan;
    for (var i = 0; i < 20 && (plan = sub.read()) == null; i++) {
      await pumpEventQueue();
    }
    expect(plan, isNotNull);
    expect([for (final p in plan!) p.notification.title], ['ミケのお薬の時間です']);
    expect(plan.single.daily, isTrue);
    expect(plan.single.notification, isA<AppNotification>());
  });
}
