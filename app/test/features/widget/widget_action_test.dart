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
/// ウィジェットの ID（Android が振る番号）
const widgetId = 7;

class FakeHost extends WidgetHost {
  final saved = <(String, String)>[];
  final removed = <String>[];
  var refreshed = 0;

  @override
  Future<void> save(String key, String value) async => saved.add((key, value));

  @override
  Future<void> refresh() async => refreshed++;

  @override
  Future<void> remove(String key) async => removed.add(key);

  List<Map<String, dynamic>> uis() => [
    for (final (k, v) in saved)
      if (k == WidgetKeys.ui(widgetId)) jsonDecode(v) as Map<String, dynamic>,
  ];
}

void main() {
  late AppDatabase db;
  late FakeHost host;
  final now = DateTime.utc(2026, 11, 5, 8);

  setUp(() async {
    db = memoryDatabase();
    host = FakeHost();
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

  /// ウィジェットからのリンク。[widget] を付けなければ、ウィジェット 7 から押したものにする
  Future<void> run(String uri, {bool widget = true}) => handleWidgetAction(
    Uri.parse(widget ? '$uri&widget=$widgetId' : uri),
    db: db,
    host: host,
    clock: () => now,
  );

  test(
    'UT-WG-14 保存して記録待ちの印を消す。結果は Android が先に出すので書き換えない。同期待ちに積み、投稿者はログイン中の人',
    () async {
      await signIn();

      await run('meowscope://widget/record?type=t1&cat=c1');

      final record = await db.select(db.records).getSingle();
      expect(
        (record.catId, record.recordTypeId, record.authorName),
        ('c1', 't1', 'はる'),
      );
      expect(await db.select(db.pendingChanges).get(), hasLength(1));
      expect(host.uis(), isEmpty);
      expect(host.removed, [WidgetKeys.pending(widgetId)]);
    },
  );

  test('UT-WG-15 異常系：記録できないときは記録せず、印を消して失敗の文を3秒出す', () async {
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
    expect(messages, List.filled(8, widgetFailedMessage));
    expect(host.removed, List.filled(8, WidgetKeys.pending(widgetId)));
    expect(
      host.uis().first['until'],
      now.add(failedDuration).millisecondsSinceEpoch,
    );
  });

  test('UT-WG-16 入っていないおうちの猫と項目には記録しない（抜けたおうちのウィジェットなど）', () async {
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

  test('UT-WG-21 今のおうちに限らず、押した項目と猫のおうちに記録する（おうちごとのウィジェット。BR-40）', () async {
    await signIn();
    // はるは h1（今のおうち）と h2 に入っている
    for (final (id, household) in [('m1', 'h1'), ('m2', 'h2')]) {
      await db
          .into(db.householdMembers)
          .insert(
            HouseholdMembersCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: household,
              userId: const Value('u1'),
            ),
          );
    }

    await run('meowscope://widget/record?type=t3&cat=c2');
    // 項目と猫のおうちが違うときは記録しない
    await run('meowscope://widget/record?type=t3&cat=c1');

    final records = await db.select(db.records).get();
    expect(
      [for (final r in records) (r.catId, r.recordTypeId)],
      [('c2', 't3')],
    );
    expect(host.removed, [
      WidgetKeys.pending(widgetId),
      WidgetKeys.pending(widgetId),
    ]);
    expect(host.uis(), hasLength(1));
  });

  test('UT-WG-22 異常系：どのウィジェットから押したか分からなければ、記録も表示の書き換えもしない', () async {
    await signIn();
    await run('meowscope://widget/record?type=t1&cat=c1', widget: false);
    await run(
      'meowscope://widget/record?type=t1&cat=c1&widget=x',
      widget: false,
    );
    expect(await db.select(db.records).get(), isEmpty);
    expect(host.saved, isEmpty);
    expect(host.removed, isEmpty);
  });

  group('UT-WG-18 ウィジェットへ渡す内容', () {
    test('同じ内容は渡し直さない。変わったら渡して描き直す。読み込み中は渡さない', () async {
      final publisher = WidgetPublisher(host);
      const a = WidgetState.needsApp();
      await publisher.publish(null);
      await publisher.publish(a);
      await publisher.publish(a);
      await publisher.publish(
        const WidgetState(
          households: [
            (
              id: 'h1',
              name: 'みけ家',
              snapshot: WidgetSnapshot(status: WidgetStatus.noButtons),
            ),
          ],
        ),
      );

      expect(
        [for (final (k, _) in host.saved) k],
        [WidgetKeys.snapshot, WidgetKeys.snapshot],
      );
      expect(host.refreshed, 2);
    });

    test('入っているおうちごとに、ボタンと記録できる猫を渡す。非表示の項目のボタンは出さない', () async {
      await signIn();
      await db
          .into(db.householdMembers)
          .insert(
            HouseholdMembersCompanion.insert(
              id: 'm2',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h2',
              userId: const Value('u1'),
            ),
          );
      final repo = WidgetButtonRepository(db);
      await repo.add(userId: 'u1', recordTypeId: 't1');
      await repo.add(userId: 'u1', recordTypeId: 't2');
      await repo.add(userId: 'u1', recordTypeId: 't3');
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

      WidgetState? state;
      for (var i = 0; i < 20 && state == null; i++) {
        await Future<void>.delayed(Duration.zero);
        state = container.read(widgetSnapshotProvider);
      }
      expect(state!.status, WidgetStatus.ready);
      // h2 はメンバーの行があり、h1 は今のおうち（行はまだない）なので後ろ
      expect([for (final h in state.households) h.id], ['h2', 'h1']);
      final h1 = state.households.firstWhere((h) => h.id == 'h1').snapshot;
      expect(h1.buttons, [
        (id: 't1', name: 'ご飯', icon: 'assets/icons/custom_other.png'),
      ]);
      expect(h1.cats, [(id: 'c1', name: 'ミケ')]);
      final h2 = state.households.firstWhere((h) => h.id == 'h2').snapshot;
      expect([for (final b in h2.buttons) b.id], ['t3']);
      expect(h2.cats, [(id: 'c2', name: 'よそ')]);
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

      WidgetState? state;
      for (var i = 0; i < 20 && state == null; i++) {
        await Future<void>.delayed(Duration.zero);
        state = container.read(widgetSnapshotProvider);
      }
      expect(state!.status, WidgetStatus.needsApp);
      expect(jsonDecode(state.toJson()), {
        'status': 'needsApp',
        'message': 'MeowScope を開いてください',
        'households': [],
      });
    });
  });
}
