import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/api/api_client.dart';
import 'package:meowscope/core/api/api_error.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/auth/domain/credentials.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

void main() {
  group('入力の決まり', () {
    test('UT-AU-03 パスワードの長さ：7・65文字は不可、8・64文字は可（境界値）', () {
      expect(Credentials.validatePassword('a' * 7), isNotNull);
      expect(Credentials.validatePassword('a' * 8), isNull);
      expect(Credentials.validatePassword('a' * 64), isNull);
      expect(Credentials.validatePassword('a' * 65), isNotNull);
      expect(Credentials.validatePassword(null), isNotNull);
    });

    test('UT-AU-04 メールアドレス：空・形でない は不可、前後の空白は除いて判定', () {
      expect(Credentials.validateEmail(''), 'メールアドレスを入力してください');
      expect(Credentials.validateEmail(null), 'メールアドレスを入力してください');
      expect(Credentials.validateEmail('haru'), 'メールアドレスの形で入力してください');
      expect(Credentials.validateEmail(' haru@example.com '), isNull);
    });

    test('UT-AU-05 名前：空白だけは不可、20文字は可・21文字は不可（境界値）', () {
      expect(Credentials.validateName('  '), '名前を入力してください');
      expect(Credentials.validateName('あ' * 20), isNull);
      expect(Credentials.validateName('あ' * 21), isNotNull);
    });

    test('UT-AU-06 全角の入力と貼り付けは、まるごと受け付けない（BR-26）', () {
      var rejected = 0;
      final formatter = AsciiOnlyFormatter(onRejected: () => rejected++);
      const old = TextEditingValue(text: 'abc');
      // 半角は受け付ける
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: 'abc!')),
        const TextEditingValue(text: 'abc!'),
      );
      // 全角が1文字でも混ざった貼り付けは、入力欄を変えない
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: 'abcｄef')),
        old,
      );
      // 空白も受け付けない
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: 'ab c')),
        old,
      );
      expect(rejected, 2);
    });

    group('IME の変換（#172）', () {
      TextEditingValue composing(String text, int start) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: start, end: text.length),
      );
      TextEditingValue fixed(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

      test('UT-AU-30 変換の途中は全角でもそのまま表示し、案内を出さない', () {
        var rejected = 0;
        final formatter = AsciiOnlyFormatter(onRejected: () => rejected++);
        final result = formatter.formatEditUpdate(
          fixed('ab'),
          composing('abすた', 2),
        );
        expect(result, composing('abすた', 2));
        expect(rejected, 0);
      });

      test('UT-AU-31 全角のまま確定したら、変換を始める前の内容に戻して案内を出す', () {
        var rejected = 0;
        final formatter = AsciiOnlyFormatter(onRejected: () => rejected++);
        formatter.formatEditUpdate(fixed('ab'), composing('abす', 2));
        formatter.formatEditUpdate(composing('abす', 2), composing('abすた', 2));
        final result = formatter.formatEditUpdate(
          composing('abすた', 2),
          fixed('abスタ'),
        );
        expect(result, fixed('ab'));
        expect(rejected, 1);
      });

      test('UT-AU-32 半角の候補で確定したら、そのまま受け付ける（文字が増えない）', () {
        var rejected = 0;
        final formatter = AsciiOnlyFormatter(onRejected: () => rejected++);
        formatter.formatEditUpdate(fixed('ab'), composing('abすた', 2));
        final result = formatter.formatEditUpdate(
          composing('abすた', 2),
          fixed('abstar@example.test'),
        );
        expect(result, fixed('abstar@example.test'));
        expect(rejected, 0);
        // 確定の後の全角の貼り付けは、今までどおり確定した内容のまま
        expect(
          formatter.formatEditUpdate(result, fixed('abstar@example.testｘ')),
          result,
        );
        expect(rejected, 1);
      });

      test('UT-AU-33 変換の始まりを覚えていないときに全角で確定したら、空に戻す', () {
        var rejected = 0;
        final formatter = AsciiOnlyFormatter(onRejected: () => rejected++);
        final result = formatter.formatEditUpdate(
          composing('すた', 0),
          fixed('スタ'),
        );
        expect(result, TextEditingValue.empty);
        expect(rejected, 1);
      });
    });
  });

  group('エラーの文', () {
    ApiError error(int? status, {String? requestId}) =>
        ApiError(status: status, code: 'X', requestId: requestId);

    test('UT-AU-07 つながらない・決めた文・5xx（問い合わせ番号あり／なし）・その他の 4xx（同値分割）', () {
      expect(error(null).isOffline, isTrue);
      expect(error(null).message(), contains('サーバーにつながりません'));
      expect(error(401).message({401: '違います'}), '違います');
      expect(
        error(500, requestId: 'req-9').message(),
        contains('問い合わせ番号：req-9'),
      );
      expect(error(503).message(), isNot(contains('問い合わせ番号')));
      // 4xx は利用者が直せる誤りなので、問い合わせ番号を出さない（ログ設計書 4章）
      expect(
        error(400, requestId: 'req-9').message(),
        isNot(contains('req-9')),
      );
    });

    test('UT-AU-08 通信の失敗から、状態コード・code・問い合わせ番号を読む。本文が JSON でなくても落ちない', () {
      final options = RequestOptions(path: '/x');
      final withBody = ApiError.from(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 409,
            data: {'code': 'CONFLICT', 'requestId': 'r1'},
          ),
        ),
      );
      expect(
        (withBody.status, withBody.code, withBody.requestId),
        (409, 'CONFLICT', 'r1'),
      );
      final textBody = ApiError.from(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 502,
            data: 'Bad Gateway',
          ),
        ),
      );
      expect((textBody.status, textBody.code), (502, null));
      expect(
        ApiError.from(DioException(requestOptions: options)).isOffline,
        isTrue,
      );
    });
  });

  group('通信の部品', () {
    late FakeServer server;
    late MemoryTokenStore tokens;
    late Dio dio;
    var expired = 0;

    setUp(() {
      server = FakeServer();
      tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(accessToken: 'old', refreshToken: 'r-old');
      expired = 0;
      dio = fakeApiClient(server, tokens, onSessionExpired: () => expired++);
    });

    test('UT-AU-09 アクセストークンを付けて送る。認証の要らない要求には付けない', () async {
      server.on('GET', '/me', (r) => const FakeResponse(200, {}));
      server.on('POST', '/auth/login', (r) => const FakeResponse(200, {}));
      await dio.get<void>('/me');
      await dio.post<void>(
        '/auth/login',
        options: Options(extra: {noAuth: true}),
      );
      expect(server.requests[0].headers['Authorization'], 'Bearer old');
      expect(server.requests[1].headers['Authorization'], isNull);
    });

    test('UT-AU-10 401 なら更新トークンで交換して、元の要求をやり直す', () async {
      server.on(
        'GET',
        '/me',
        (r) => r.headers['Authorization'] == 'Bearer new'
            ? const FakeResponse(200, {'ok': true})
            : const FakeResponse(401, {'code': 'UNAUTHORIZED'}),
      );
      server.on(
        'POST',
        '/auth/refresh',
        (r) => const FakeResponse(200, {
          'accessToken': 'new',
          'refreshToken': 'r-new',
        }),
      );

      final response = await dio.get<Map<String, dynamic>>('/me');

      expect(response.data, {'ok': true});
      expect(server.sentTo('/auth/refresh').single.data, {
        'refreshToken': 'r-old',
      });
      expect(tokens.tokens?.refreshToken, 'r-new');
      expect(expired, 0);
    });

    test('UT-AU-11 交換も 401 なら、トークンを消して知らせ、元のエラーを返す', () async {
      server.on('GET', '/me', (r) => const FakeResponse(401));
      server.on('POST', '/auth/refresh', (r) => const FakeResponse(401));

      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

      expect(tokens.tokens, isNull);
      expect(expired, 1);
    });

    test('UT-AU-12 交換がつながらないときは、トークンを残して元のエラーを返す', () async {
      server.on('GET', '/me', (r) => const FakeResponse(401));
      server.on('POST', '/auth/refresh', (r) => const FakeResponse.offline());

      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

      expect(tokens.tokens?.refreshToken, 'r-old');
      expect(expired, 0);
    });

    test('UT-AU-13 やり直しても 401 なら、もう交換しない。トークンがなければ交換しない', () async {
      server.on('GET', '/me', (r) => const FakeResponse(401));
      server.on(
        'POST',
        '/auth/refresh',
        (r) => const FakeResponse(200, {
          'accessToken': 'new',
          'refreshToken': 'r-new',
        }),
      );
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(server.sentTo('/auth/refresh'), hasLength(1));

      tokens.tokens = null;
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(server.sentTo('/auth/refresh'), hasLength(1));
    });

    test('UT-AU-14 401 以外のエラーと、認証の要らない要求の 401 は、そのまま返す', () async {
      server.on('GET', '/me', (r) => const FakeResponse(500));
      server.on('POST', '/auth/login', (r) => const FakeResponse(401));
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      await expectLater(
        dio.post<void>('/auth/login', options: Options(extra: {noAuth: true})),
        throwsA(isA<DioException>()),
      );
      expect(server.sentTo('/auth/refresh'), isEmpty);
    });

    test('UT-AU-15 別の要求がすでに交換していたら、交換せずに新しいトークンでやり直す', () async {
      // 要求を送った後に、別の要求が交換を済ませた状態を作る
      server.on('GET', '/race', (r) {
        if (r.headers['Authorization'] == 'Bearer newer') {
          return const FakeResponse(200);
        }
        tokens.tokens = const AuthTokens(
          accessToken: 'newer',
          refreshToken: 'r-newer',
        );
        return const FakeResponse(401);
      });

      await dio.get<void>('/race');

      expect(server.sentTo('/auth/refresh'), isEmpty);
      expect(
        server.sentTo('/race').last.headers['Authorization'],
        'Bearer newer',
      );
    });
  });

  group('ログインとログアウト', () {
    late AppDatabase db;
    late FakeServer server;
    late MemoryTokenStore tokens;
    late AuthRepository repo;

    setUp(() {
      db = memoryDatabase();
      server = FakeServer();
      tokens = MemoryTokenStore();
      repo = AuthRepository(db, fakeApiClient(server, tokens), tokens);
    });
    tearDown(() => db.close());

    Future<Map<String, String>> states() async => {
      for (final s in await db.select(db.appStates).get()) s.key: s.value,
    };

    test('UT-AU-16 ログイン：トークンを保管し、ユーザーをセッションにする。メールアドレスの前後の空白を除く', () async {
      server.on('POST', '/auth/login', (r) => FakeResponse(200, authBody()));

      await repo.login(email: ' haru@example.com ', password: 'Passw0rd!');

      expect(server.requests.single.data, {
        'email': 'haru@example.com',
        'password': 'Passw0rd!',
      });
      expect(tokens.tokens?.accessToken, 'access-1');
      expect(await states(), {
        'session.userId': 'u1',
        'session.userName': 'はる',
      });
      final user = await repo.watchUser().first;
      expect((user?.id, user?.name), ('u1', 'はる'));
    });

    test('UT-AU-17 新規登録：名前の前後の空白を除いて送り、ログインした状態になる', () async {
      server.on('POST', '/auth/register', (r) => FakeResponse(201, authBody()));

      await repo.register(
        email: 'haru@example.com',
        password: 'Passw0rd!',
        displayName: ' はる ',
      );

      expect((server.requests.single.data as Map)['displayName'], 'はる');
      expect((await states())['session.userId'], 'u1');
    });

    test('UT-AU-18 異常系：失敗は ApiError になり、トークンもセッションも残さない', () async {
      server.on(
        'POST',
        '/auth/login',
        (r) => const FakeResponse(401, {'code': 'UNAUTHORIZED'}),
      );

      await expectLater(
        repo.login(email: 'haru@example.com', password: 'x'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
      );
      expect(tokens.tokens, isNull);
      expect(await states(), isEmpty);
    });

    test('UT-AU-19 ログアウト：サーバーへ知らせ、トークンとセッションを消す。未送信がなければ同期済みのデータも消す', () async {
      server.on('POST', '/auth/login', (r) => FakeResponse(200, authBody()));
      server.on('POST', '/auth/logout', (r) => const FakeResponse(204));
      await repo.login(email: 'haru@example.com', password: 'Passw0rd!');
      await db.batch(
        (b) => b.insertAll(db.appStates, [
          AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
          AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
          AppStatesCompanion.insert(key: 'sync.lastSeq.u1', value: '10'),
          AppStatesCompanion.insert(key: 'settings.weekStart', value: 'monday'),
        ]),
      );
      await addHousehold(db, 'h1');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');

      await repo.logout();

      expect(server.sentTo('/auth/logout').single.data, {
        'refreshToken': 'refresh-1',
      });
      expect(
        server.sentTo('/auth/logout').single.headers['Authorization'],
        'Bearer access-1',
      );
      expect(tokens.tokens, isNull);
      // 端末の設定は残し、同期の位置とおうちの記憶は消す（次は全件を取り直す）
      expect(await states(), {'settings.weekStart': 'monday'});
      expect(await db.select(db.cats).get(), isEmpty);
      expect(await db.select(db.households).get(), isEmpty);
      expect(await repo.watchUser().first, isNull);
    });

    test('UT-AU-29 ログアウト：未送信の変更があれば、データと同期の位置を残す（API 設計書 2章）', () async {
      server.on('POST', '/auth/login', (r) => FakeResponse(200, authBody()));
      server.on('POST', '/auth/logout', (r) => const FakeResponse(204));
      await repo.login(email: 'haru@example.com', password: 'Passw0rd!');
      await addHousehold(db, 'h1');
      await db.batch(
        (b) => b
          ..insert(
            db.appStates,
            AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
          )
          ..insert(
            db.pendingChanges,
            PendingChangesCompanion.insert(
              userId: 'u1',
              targetTable: 'households',
              rowId: 'h1',
              operation: 'upsert',
              payload: '{}',
            ),
          ),
      );

      await repo.logout();

      expect(await states(), {'household.u1': 'h1'});
      expect(await db.select(db.households).get(), hasLength(1));
      expect(await db.select(db.pendingChanges).get(), hasLength(1));
    });

    test('UT-AU-20 ログアウト：つながらなくても端末ではログアウトする。トークンがなければ知らせない', () async {
      server.on('POST', '/auth/login', (r) => FakeResponse(200, authBody()));
      server.on('POST', '/auth/logout', (r) => const FakeResponse.offline());
      await repo.login(email: 'haru@example.com', password: 'Passw0rd!');

      await repo.logout();
      expect(await states(), isEmpty);

      await repo.logout();
      expect(server.sentTo('/auth/logout'), hasLength(1));
    });

    test('UT-AU-21 入り直すと前のおうちに戻り、別の人のおうちは見せない（API 設計書 2章）', () async {
      await db.batch(
        (b) => b.insertAll(db.appStates, [
          AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
          // 前の人のおうちの選択が残っていた場合
          AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        ]),
      );
      server.on(
        'POST',
        '/auth/login',
        (r) => FakeResponse(
          200,
          (r.data as Map)['email'] == 'natsu@example.com'
              ? authBody(userId: 'u2', name: 'なつ')
              : authBody(),
        ),
      );

      await repo.login(email: 'natsu@example.com', password: 'Passw0rd!');
      expect((await states())['session.householdId'], isNull);

      await repo.login(email: 'haru@example.com', password: 'Passw0rd!');
      expect((await states())['session.householdId'], 'h1');
    });
  });
}
