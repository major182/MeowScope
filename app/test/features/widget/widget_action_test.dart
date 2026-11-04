import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/widget/data/widget_action.dart';
import 'package:meowscope/features/widget/data/widget_button_repository.dart';
import 'package:meowscope/features/widget/data/widget_host.dart';
import 'package:meowscope/features/widget/data/widget_publisher.dart';
import 'package:meowscope/features/widget/domain/widget_snapshot.dart';

import '../../helpers/test_db.dart';

/// 渡した内容を覚えておく口
class FakeHost extends WidgetHost {
  final saved = <(String, String)>[];
  var refreshed = 0;

  @override
  Future<void> save(String key, String value) async => saved.add((key, value));

  @override
  Future<void> refresh() async => refreshed++;

  List<Map<String, dynamic>> uis() => [
    for (final (k, v) in saved)
      if (k == WidgetKeys.ui) jsonDecode(v) as Map<String, dynamic>,
  ];
}

void main() {
  late AppDatabase db;
  late FakeHost host;
  final now = DateTime.utc(2026, 11, 5, 8);
  final waited = <Duration>[];

  setUp(() async {
    db = memoryDatabase();
    host = FakeHost();
    waited.clear();
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h2', name: 'よそ');
    await addCat(
      db,
      id: 'c3',
      householdId: 'h1',
      name: 'ハナ',
      status: 'farewell',
    );
    for (final (id, household, hidden) in [
      ('t1', 'h1', false),
      ('t2', 'h1', true),
      ('t3', 'h2', false),
    ]) {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: household,
              name: id == 't1' ? 'ご飯' : id,
              kind: 'custom',
              hidden: Value(hidden),
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<void> signIn({bool household = true}) => db.batch(
    (b) => b.insertAll(db.appStates, [
      AppStatesCompanion.insert(key: SessionKeys.userId, value: 'u1'),
      AppStatesCompanion.insert(key: SessionKeys.userName, value: 'はる'),
      if (household)
        AppStatesCompanion.insert(key: SessionKeys.householdId, value: 'h1'),
    ]),
  );

  Future<void> run(String uri) => handleWidgetAction(
    Uri.parse(uri),
    db: db,
    host: host,
    clock: () => now,
    wait: (d) async => waited.add(d),
  );

  test('UT-WG-14 記録して結果を2秒出し、ボタンに戻す。記録は同期待ちに積み、投稿者はログイン中の人', () async {
    await signIn();

    await run('meowscope://widget/record?type=t1&cat=c1');

    final record = await db.select(db.records).getSingle();
    expect(
      (record.catId, record.recordTypeId, record.authorName),
      ('c1', 't1', 'はる'),
    );
    expect(await db.select(db.pendingChanges).get(), hasLength(1));
    expect(host.uis(), [
      {
        'mode': 'done',
        'message': '✓ ミケのご飯を記録しました',
        'until': now.add(doneDuration).millisecondsSinceEpoch,
      },
      {'mode': 'buttons'},
    ]);
    expect(waited, [doneDuration]);
    expect(host.refreshed, 2);
  });

  test('UT-WG-15 異常系：記録できないときは記録せず、その旨を出す', () async {
    const failed = '記録できませんでした。アプリを開いてください';
    // ログインしていない
    await run('meowscope://widget/record?type=t1&cat=c1');
    await signIn();
    for (final uri in [
      'meowscope://widget/record?type=t1', // 猫がない
      'meowscope://widget/record?cat=c1', // 項目がない
      'meowscope://widget/record?type=t1&cat=c2', // 別のおうちの猫
      'meowscope://widget/record?type=t3&cat=c1', // 別のおうちの項目
      'meowscope://widget/record?type=t2&cat=c1', // 非表示の項目
      'meowscope://widget/record?type=t1&cat=c3', // お別れした猫
      'meowscope://widget/record?type=t1&cat=none', // ない猫
    ]) {
      await run(uri);
    }
    expect(await db.select(db.records).get(), isEmpty);
    final messages = [
      for (final ui in host.uis())
        if (ui['mode'] == 'done') ui['message'],
    ];
    expect(messages, List.filled(8, failed));
  });

  test('UT-WG-16 おうちが選ばれていなければ記録しない', () async {
    await signIn(household: false);
    await run('meowscope://widget/record?type=t1&cat=c1');
    expect(await db.select(db.records).get(), isEmpty);
  });

  test('UT-WG-17 知らないリンクは何もしない', () async {
    await signIn();
    for (final uri in [
      'https://widget/record?type=t1&cat=c1',
      'meowscope://invite/record?type=t1&cat=c1',
      'meowscope://widget/other?type=t1&cat=c1',
    ]) {
      await run(uri);
    }
    expect(await db.select(db.records).get(), isEmpty);
    expect(host.saved, isEmpty);
  });

  group('UT-WG-18 ウィジェットへ渡す内容', () {
    test('同じ内容は渡し直さない。変わったら渡して、表示をボタンに戻す。読み込み中は渡さない', () async {
      final publisher = WidgetPublisher(host);
      const a = WidgetSnapshot(status: WidgetStatus.needsApp);
      await publisher.publish(null);
      await publisher.publish(a);
      await publisher.publish(a);
      await publisher.publish(
        const WidgetSnapshot(status: WidgetStatus.noButtons),
      );

      expect(
        [for (final (k, _) in host.saved) k],
        [
          WidgetKeys.snapshot,
          WidgetKeys.ui,
          WidgetKeys.snapshot,
          WidgetKeys.ui,
        ],
      );
      expect(host.uis(), [
        {'mode': 'buttons'},
        {'mode': 'buttons'},
      ]);
    });

    test('ログイン中のおうちのボタンと記録できる猫を渡す。非表示の項目のボタンは出さない', () async {
      await signIn();
      final repo = WidgetButtonRepository(db);
      await repo.add(userId: 'u1', recordTypeId: 't1');
      await repo.add(userId: 'u1', recordTypeId: 't2');
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(widgetSnapshotProvider, (_, _) {});
      addTearDown(sub.close);

      WidgetSnapshot? snapshot;
      for (var i = 0; i < 20 && snapshot == null; i++) {
        await Future<void>.delayed(Duration.zero);
        snapshot = container.read(widgetSnapshotProvider);
      }
      expect(snapshot!.status, WidgetStatus.ready);
      expect(snapshot.buttons, [(id: 't1', name: 'ご飯')]);
      expect(snapshot.cats, [(id: 'c1', name: 'ミケ')]);
    });

    test('ログインしていなければ、アプリを開く内容を渡す', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(widgetSnapshotProvider, (_, _) {});
      addTearDown(sub.close);

      WidgetSnapshot? snapshot;
      for (var i = 0; i < 20 && snapshot == null; i++) {
        await Future<void>.delayed(Duration.zero);
        snapshot = container.read(widgetSnapshotProvider);
      }
      expect(snapshot!.status, WidgetStatus.needsApp);
    });
  });
}
