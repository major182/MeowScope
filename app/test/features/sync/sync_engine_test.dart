import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/sync/data/sync_engine.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;
  late SyncEngine engine;
  final now = DateTime.utc(2026, 11, 3, 12);

  setUp(() {
    db = memoryDatabase();
    server = FakeServer();
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    engine = SyncEngine(
      db,
      fakeApiClient(server, tokens),
      tokens,
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  /// 送られた変更をすべて [status] にし、[changes] を返すサーバー
  void answer({
    String status = 'applied',
    String? reason,
    String? field,
    List<Map<String, Object?>> changes = const [],
    int nextSeq = 10,
    bool hasMore = false,
    bool fullResync = false,
  }) {
    server.on('POST', '/sync', (r) {
      final sent = ((r.data as Map)['changes'] as List).cast<Map>();
      return FakeResponse(200, {
        'results': [
          for (final c in sent)
            {'id': c['id'], 'status': status, 'reason': reason, 'field': field},
        ],
        'changes': changes,
        'nextSeq': nextSeq,
        'hasMore': hasMore,
        'fullResyncRequired': fullResync,
      });
    });
  }

  Future<void> pending(String table, String rowId, {String op = 'upsert'}) => db
      .into(db.pendingChanges)
      .insert(
        PendingChangesCompanion.insert(
          userId: 'u1',
          targetTable: table,
          rowId: rowId,
          operation: op,
          payload: '{}',
        ),
      );

  Future<Map<String, String>> states() async => {
    for (final s in await db.select(db.appStates).get()) s.key: s.value,
  };

  List<Map> sentChanges([int index = 0]) =>
      ((server.sentTo('/sync')[index].data as Map)['changes'] as List)
          .cast<Map>();

  Map<String, Object?> pulled(
    String table,
    String id,
    Map<String, Object?> data, {
    int seq = 1,
    String? deletedAt,
  }) => {
    'table': table,
    'id': id,
    'seq': seq,
    'updatedAt': '2026-11-03T01:00:00Z',
    'deletedAt': deletedAt,
    'data': data,
  };

  test('UT-SY-01 トークンがなければ送らず、ログインし直しを返す', () async {
    tokens.tokens = null;
    expect(await engine.run('u1'), isA<SyncNeedsLogin>());
    expect(server.requests, isEmpty);
  });

  test('UT-SY-02 端末で作ったおうちを、標準の項目と一緒に POST /households で送り、続けて同期する', () async {
    await addHousehold(db, 'h1');
    for (final (id, kind) in [('t1', 'food'), ('t2', 'custom')]) {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: kind,
              kind: kind,
            ),
          );
    }
    await pending('households', 'h1', op: 'create');
    server.on('POST', '/households', (r) => const FakeResponse(201, {}));
    answer();

    expect(await engine.run('u1'), isA<SyncSucceeded>());

    final body = server.sentTo('/households').single.data as Map;
    expect(body['id'], 'h1');
    expect(body['name'], 'みけ家');
    // 独自の項目は同期で送る
    expect((body['recordTypes'] as List).map((t) => t['id']), ['t1']);
    expect(server.sentTo('/sync'), hasLength(1));
    expect(await db.select(db.pendingChanges).get(), isEmpty);
  });

  test('UT-SY-03 同じ行の変更は1つにまとめ、送る時点の内容を送る。成功したら同期待ちを消し、位置と時刻を残す', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await pending('cats', 'c1');
    await (db.update(db.cats)..where((c) => c.id.equals('c1'))).write(
      CatsCompanion(
        name: const Value('タマ'),
        birthDate: Value(DateTime(2020, 4, 1)),
      ),
    );
    await pending('cats', 'c1');
    answer(nextSeq: 42);

    await engine.run('u1');

    final changes = sentChanges();
    expect(changes, hasLength(1));
    expect(changes.single['table'], 'cats');
    expect(changes.single['data'], {
      'householdId': 'h1',
      'name': 'タマ',
      'birthDate': '2020-04-01',
      'sex': null,
      'conditions': null,
      'status': 'active',
    });
    expect((server.sentTo('/sync').single.data as Map)['lastSeq'], 0);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    final s = await states();
    expect(s['sync.lastSeq.u1'], '42');
    expect(s['sync.lastSyncedAt.u1'], now.toIso8601String());
  });

  test('UT-SY-04 異常系：つながらなければ同期待ちを残し、試した回数を増やす', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await pending('cats', 'c1');
    server.on('POST', '/sync', (r) => const FakeResponse.offline());

    final outcome = await engine.run('u1');

    expect(outcome, isA<SyncFailed>());
    expect((outcome as SyncFailed).error.isOffline, isTrue);
    final left = await db.select(db.pendingChanges).getSingle();
    expect(left.attempts, 1);
    expect((await states())['sync.lastSyncedAt.u1'], isNull);
  });

  test('UT-SY-05 サーバーの異常は問い合わせ番号を残し、次に成功したら消す', () async {
    server.on(
      'POST',
      '/sync',
      (r) => const FakeResponse(500, {
        'code': 'INTERNAL_ERROR',
        'requestId': 'req-1',
      }),
    );
    expect(await engine.run('u1'), isA<SyncFailed>());
    expect((await states())['sync.lastRequestId.u1'], 'req-1');

    answer();
    await engine.run('u1');
    expect((await states())['sync.lastRequestId.u1'], isNull);
  });

  test('UT-SY-06 401（トークンの交換にも失敗）なら、ログインし直しを返す', () async {
    server.on('POST', '/sync', (r) => const FakeResponse(401));
    server.on('POST', '/auth/refresh', (r) => const FakeResponse(401));
    expect(await engine.run('u1'), isA<SyncNeedsLogin>());
  });

  test('UT-SY-07 受け取った変更を反映する。記録が猫より先に届いても入る', () async {
    answer(
      changes: [
        pulled('households', 'h1', {'name': 'みけ家'}, seq: 1),
        pulled('household_members', 'm1', {
          'householdId': 'h1',
          'userId': 'u2',
          'displayName': 'なつ',
        }, seq: 2),
        pulled('records', 'r1', {
          'catId': 'c1',
          'recordTypeId': 't1',
          'recordedAt': '2026-11-03T08:00:00Z',
          'authorId': 'u2',
          'authorName': 'なつ',
          'valueNumber': 4.2,
          'level': 'normal',
          'detail': {'a': 1},
          'memo': 'よく食べた',
        }, seq: 3),
        pulled('record_types', 't1', {
          'householdId': 'h1',
          'name': 'ご飯',
          'icon': 'food',
          'kind': 'food',
          'sortOrder': 0,
          'hidden': false,
        }, seq: 4),
        pulled('cats', 'c1', {
          'householdId': 'h1',
          'name': 'ミケ',
          'birthDate': '2020-04-01',
          'sex': 'female',
          'conditions': null,
          'status': 'active',
        }, seq: 5),
        pulled('users', 'u2', {'displayName': 'なっちゃん'}, seq: 6),
        pulled('user_settings', 's1', {'weekStart': 'monday'}, seq: 7),
      ],
    );

    expect(await engine.run('u1'), isA<SyncSucceeded>());

    final record = await db.select(db.records).getSingle();
    expect(
      (
        record.memo,
        record.valueNumber,
        record.authorId,
        record.detail,
        record.serverSeq,
      ),
      ('よく食べた', 4.2, 'u2', '{"a":1}', 3),
    );
    expect(record.recordedAt.toUtc(), DateTime.utc(2026, 11, 3, 8));
    final cat = await db.select(db.cats).getSingle();
    expect(
      (cat.name, cat.sex, cat.birthDate),
      ('ミケ', 'female', DateTime(2020, 4, 1)),
    );
    final member = await db.select(db.householdMembers).getSingle();
    expect(member.displayName, 'なっちゃん');
    expect((await states())['settings.weekStart'], 'monday');
    // 参照の確認は元に戻っている
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.single, 1);
  });

  test('UT-SY-08 同期の最中にできた変更がある行は、受け取った内容で上書きしない', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: '端末の名前');
    // 同期の要求の最中に、利用者が猫を編集した（新しい同期待ちができた）
    server.on('POST', '/sync', (r) async {
      await pending('cats', 'c1');
      return FakeResponse(200, {
        'results': [],
        'changes': [
          pulled('cats', 'c1', {
            'householdId': 'h1',
            'name': 'サーバーの名前',
            'status': 'active',
          }),
        ],
        'nextSeq': 2,
        'hasMore': false,
        'fullResyncRequired': false,
      });
    });

    await engine.run('u1');

    expect((await db.select(db.cats).getSingle()).name, '端末の名前');
    // 編集は次の同期で送る
    expect(await db.select(db.pendingChanges).get(), hasLength(1));
  });

  test('UT-SY-09 自分がおうちから外れたら、そのおうちのデータを消し、選択を外す', () async {
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h2', name: 'タマ');
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
      ]),
    );
    answer(
      changes: [
        pulled('household_members', 'm1', {
          'householdId': 'h1',
          'userId': 'u1',
          'displayName': 'はる',
        }, deletedAt: '2026-11-03T02:00:00Z'),
      ],
    );

    await engine.run('u1');

    expect((await db.select(db.cats).get()).map((c) => c.id), ['c2']);
    expect((await db.select(db.households).get()).map((h) => h.id), ['h2']);
    final s = await states();
    expect(s['session.householdId'], isNull);
    expect(s['household.u1'], isNull);
  });

  test('UT-SY-10 おうちを選んでいなければ、受け取ったおうちを選ぶ（機種変更の後）', () async {
    answer(
      changes: [
        pulled('households', 'h1', {'name': 'みけ家'}),
        pulled('household_members', 'm1', {
          'householdId': 'h1',
          'userId': 'u1',
          'displayName': 'はる',
        }, seq: 2),
      ],
    );

    await engine.run('u1');

    final s = await states();
    expect(s['session.householdId'], 'h1');
    expect(s['household.u1'], 'h1');
  });

  test('UT-SY-11 続きがあれば続けて呼び、全件の取り直しなら位置を 0 に戻して呼び直す', () async {
    var calls = 0;
    server.on('POST', '/sync', (r) {
      calls++;
      final last = (r.data as Map)['lastSeq'];
      return FakeResponse(200, {
        'results': [],
        'changes': [],
        'nextSeq': calls == 1 ? 5 : (calls == 2 ? 7 : 3),
        'hasMore': calls == 1,
        'fullResyncRequired': calls == 2 && last == 5,
      });
    });

    await engine.run('u1');

    expect(server.sentTo('/sync').map((r) => (r.data as Map)['lastSeq']), [
      0,
      5,
      0,
    ]);
    expect((await states())['sync.lastSeq.u1'], '3');
  });

  test('UT-SY-12 受け付けられなかった変更は送り直さず、行ごとに理由と項目を残す。同じ行は置き換え、送れたら消す', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await pending('cats', 'c1');
    answer(status: 'rejected', reason: 'invalid', field: 'name');

    final outcome = await engine.run('u1');
    expect((outcome as SyncSucceeded).rejected, 1);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    var rows = await db.select(db.rejectedChanges).get();
    expect(
      rows.map((r) => (r.userId, r.targetTable, r.rowId, r.reason, r.field)),
      [('u1', 'cats', 'c1', 'invalid', 'name')],
    );
    expect(rows.single.rejectedAt.isAtSameMomentAs(now), isTrue);

    // 同じ行がまた送れなければ、新しい理由で置き換える
    await pending('cats', 'c1');
    answer(status: 'rejected', reason: 'forbidden');
    await engine.run('u1');
    rows = await db.select(db.rejectedChanges).get();
    expect(rows.map((r) => (r.reason, r.field)), [('forbidden', null)]);

    // 送れたら（反映・同じ内容）、送れなかった記録から外す
    await pending('cats', 'c1');
    answer(status: 'ignored');
    await engine.run('u1');
    expect(await db.select(db.rejectedChanges).get(), isEmpty);
  });

  test('UT-SY-13 境界値：500行は1回で、501行は2回に分けて送る', () async {
    await addHousehold(db, 'h1');
    for (var i = 0; i < 501; i++) {
      await addCat(db, id: 'c$i', householdId: 'h1', name: 'ねこ$i');
      await pending('cats', 'c$i');
    }
    answer();

    await engine.run('u1');

    expect(sentChanges(0), hasLength(500));
    expect(sentChanges(1), hasLength(1));
    expect(await db.select(db.pendingChanges).get(), isEmpty);
  });

  test('UT-SY-14 週の始まりと、記録・記録項目・おうちの名前を送る。なくなった行は送らずに同期待ちから消す', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await db
        .into(db.recordTypes)
        .insert(
          RecordTypesCompanion.insert(
            id: 't1',
            createdAt: testTime,
            updatedAt: testTime,
            householdId: 'h1',
            name: '通院',
            icon: const Value('custom_vet'),
            kind: 'custom',
            hidden: const Value(true),
          ),
        );
    await db
        .into(db.records)
        .insert(
          RecordsCompanion.insert(
            id: 'r1',
            createdAt: testTime,
            updatedAt: testTime,
            deletedAt: Value(testTime),
            catId: 'c1',
            recordTypeId: 't1',
            recordedAt: DateTime.utc(2026, 11, 3, 8),
            authorName: 'はる',
            valueNumber: const Value(4.5),
            detail: const Value('{"x":1}'),
          ),
        );
    await db
        .into(db.appStates)
        .insert(
          AppStatesCompanion.insert(key: 'settings.weekStart', value: 'monday'),
        );
    await pending('user_settings', 'u1');
    await pending('records', 'r1');
    await pending('record_types', 't1');
    await pending('households', 'h1');
    await pending('records', 'gone');
    answer();

    await engine.run('u1');

    final changes = {for (final c in sentChanges()) c['table']: c};
    expect(
      changes.keys,
      unorderedEquals([
        'user_settings',
        'records',
        'record_types',
        'households',
      ]),
    );
    expect(changes['user_settings']!['data'], {'weekStart': 'monday'});
    expect(changes['records']!['deletedAt'], testTime.toIso8601String());
    expect((changes['records']!['data'] as Map)['detail'], {'x': 1});
    expect(
      (changes['records']!['data'] as Map)['recordedAt'],
      '2026-11-03T08:00:00.000Z',
    );
    expect((changes['record_types']!['data'] as Map)['hidden'], true);
    expect(changes['households']!['data'], {'name': 'みけ家'});
    expect(await db.select(db.pendingChanges).get(), isEmpty);
  });

  test('UT-SY-15 おうちの作成が 404（他の人の ID）なら、理由（not_found）を残して送り直さない', () async {
    await addHousehold(db, 'h1');
    await pending('households', 'h1', op: 'create');
    server.on('POST', '/households', (r) => const FakeResponse(404));
    answer();

    final outcome = await engine.run('u1');

    expect((outcome as SyncSucceeded).rejected, 1);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    expect(
      (await db.select(db.rejectedChanges).get()).map(
        (r) => (r.targetTable, r.rowId, r.reason),
      ),
      [('households', 'h1', 'not_found')],
    );
  });

  test('UT-SY-16 異常系：おうちの作成がつながらなければ、同期待ちを残して失敗を返す', () async {
    await addHousehold(db, 'h1');
    await pending('households', 'h1', op: 'create');
    server.on('POST', '/households', (r) => const FakeResponse.offline());

    expect(await engine.run('u1'), isA<SyncFailed>());
    expect(await db.select(db.pendingChanges).get(), hasLength(1));
    expect(server.sentTo('/sync'), isEmpty);
  });

  test('UT-SY-17 別のユーザーの同期待ちは送らない（API 設計書 2章）', () async {
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await db
        .into(db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            userId: 'other',
            targetTable: 'cats',
            rowId: 'c1',
            operation: 'upsert',
            payload: '{}',
          ),
        );
    answer();

    await engine.run('u1');

    expect(sentChanges(), isEmpty);
    expect(await db.select(db.pendingChanges).get(), hasLength(1));
  });

  test('UT-SY-18 おうちの作成の要求が 400 でも、送り直さない', () async {
    await addHousehold(db, 'h1');
    await pending('households', 'h1', op: 'create');
    server.on('POST', '/households', (r) => const FakeResponse(400));
    answer();

    await engine.run('u1');
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    expect(
      (await db.select(db.rejectedChanges).get()).single.reason,
      'invalid',
    );
    expect(server.requests.whereType<RequestOptions>(), hasLength(2));
  });

  test('UT-SY-27 ウィジェットのボタンを送り、受け取ったボタンは自分のものとして入れる（BR-22）', () async {
    await addHousehold(db, 'h1');
    for (final id in ['t1', 't2']) {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: id,
              kind: 'custom',
            ),
          );
    }
    await db
        .into(db.widgetButtons)
        .insert(
          WidgetButtonsCompanion.insert(
            id: 'w1',
            createdAt: testTime,
            updatedAt: testTime,
            deletedAt: Value(testTime),
            userId: 'u1',
            recordTypeId: 't1',
            sortOrder: const Value(2),
          ),
        );
    await pending('widget_buttons', 'w1');
    answer(
      changes: [
        pulled('widget_buttons', 'w2', {
          'recordTypeId': 't2',
          'sortOrder': 1,
        }, seq: 3),
      ],
    );

    await engine.run('u1');

    final sent = sentChanges().single;
    expect(sent['table'], 'widget_buttons');
    expect(sent['data'], {'recordTypeId': 't1', 'sortOrder': 2});
    expect(sent['deletedAt'], testTime.toIso8601String());
    final got = await (db.select(
      db.widgetButtons,
    )..where((w) => w.id.equals('w2'))).getSingle();
    expect(
      (got.userId, got.recordTypeId, got.sortOrder, got.serverSeq),
      ('u1', 't2', 1, 3),
    );
  });

  group('全件の取り直しの後の片付け', () {
    /// 端末に、サーバーから受け取った猫（serverSeq あり）と記録を置く
    Future<void> local(String catId, {int? seq = 1}) async {
      await db
          .into(db.cats)
          .insert(
            CatsCompanion.insert(
              id: catId,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: catId,
              serverSeq: Value(seq),
            ),
          );
    }

    Future<List<String>> cats() async => [
      for (final c in await db.select(db.cats).get()) c.id,
    ];

    /// 1回目は全件の取り直しを指示し、2回目に [changes] を返すサーバー
    void resync(List<Map<String, Object?>> changes, {bool hasMore = false}) {
      var calls = 0;
      server.on('POST', '/sync', (r) {
        calls++;
        return FakeResponse(200, {
          'results': [],
          'changes': calls == 1 ? [] : changes,
          'nextSeq': 9,
          'hasMore': calls > 1 && hasMore && calls < 3,
          'fullResyncRequired': calls == 1,
        });
      });
    }

    test('UT-SY-28 全件を取り直したら、受け取らなかった行（サーバーにない行）を端末から消す。'
        '受け取った行・この同期で送った行・送っていない変更のある行・まだ送ったことのない行は残す', () async {
      await addHousehold(db, 'h1');
      await (db.update(db.households)..where((h) => h.id.equals('h1'))).write(
        const HouseholdsCompanion(serverSeq: Value(1)),
      );
      await local('kept');
      await local('gone');
      await local('pending');
      await local('new', seq: null);
      await pending('cats', 'pending');
      resync([
        pulled('households', 'h1', {'name': 'みけ家'}),
        pulled('cats', 'kept', {
          'householdId': 'h1',
          'name': 'kept',
          'status': 'active',
        }),
      ]);

      await engine.run('u1');

      expect(await cats(), unorderedEquals(['kept', 'pending', 'new']));
      expect(await db.select(db.households).get(), hasLength(1));
    });

    test('UT-SY-29 全件の取り直しでなければ、受け取らなかった行は消さない', () async {
      await addHousehold(db, 'h1');
      await local('kept');
      answer();

      await engine.run('u1');

      expect(await cats(), ['kept']);
    });

    test('UT-SY-30 異常系：取り直しの途中で通信が切れたら、何も消さない', () async {
      await addHousehold(db, 'h1');
      await local('kept');
      var calls = 0;
      server.on('POST', '/sync', (r) {
        calls++;
        if (calls == 1) {
          return const FakeResponse(200, {
            'results': [],
            'changes': [],
            'nextSeq': 9,
            'hasMore': false,
            'fullResyncRequired': true,
          });
        }
        throw DioException.connectionError(
          requestOptions: r,
          reason: 'offline',
        );
      });

      await engine.run('u1');

      expect(await cats(), ['kept']);
    });
  });

  test('UT-SY-31 通知の設定を送る：端末で決めた項目だけを送り、決めていない項目は送らない（既定で上書きしない）', () async {
    await pending('user_settings', 'u1');
    answer();
    await engine.run('u1');
    expect(sentChanges().single['data'], {'weekStart': 'sunday'});

    await db
        .into(db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(
            key: 'settings.notifications',
            value: '{"family":false}',
          ),
        );
    await db
        .into(db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(key: 'settings.reminderHours', value: '12'),
        );
    await db
        .into(db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(
            key: 'settings.anomalyMethod',
            value: 'threshold',
          ),
        );
    await pending('user_settings', 'u1');
    await engine.run('u1');
    expect(sentChanges(1).single['data'], {
      'weekStart': 'sunday',
      'notifications': {'family': false},
      'reminderHours': 12,
      'anomalyMethod': 'threshold',
    });
  });

  test('UT-SY-32 通知の設定を受け取る：値のある項目だけを置き、記録忘れの時間が空（オフ）なら今の値を残す', () async {
    answer(
      changes: [
        pulled('user_settings', 's1', {
          'weekStart': 'monday',
          'notifications': {'birthday': false},
          'reminderHours': 8,
          'anomalyMethod': 'threshold',
        }, seq: 7),
      ],
    );
    await engine.run('u1');
    var s = await states();
    expect(s['settings.notifications'], '{"birthday":false}');
    expect(s['settings.reminderHours'], '8');
    expect(s['settings.anomalyMethod'], 'threshold');

    answer(
      changes: [
        pulled('user_settings', 's1', {
          'weekStart': 'monday',
          'notifications': null,
          'reminderHours': null,
          'anomalyMethod': 'statistical',
        }, seq: 8),
      ],
    );
    await engine.run('u1');
    s = await states();
    expect(s['settings.reminderHours'], '8');
    expect(s['settings.notifications'], '{"birthday":false}');
    expect(s['settings.anomalyMethod'], 'statistical');
  });
}
