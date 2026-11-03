import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meowscope/core/api/api_client.dart';
import 'package:meowscope/features/auth/data/token_store.dart';

/// メモリーに置くトークンの保管場所
class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}

/// 偽のサーバーの応答
class FakeResponse {
  const FakeResponse(this.status, [this.body]);

  /// つながらない（応答がない）ことを表す
  const FakeResponse.offline() : status = 0, body = null;

  final int status;
  final Object? body;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(RequestOptions request);

/// 本物の通信の代わりに、決めた応答を返す（dio の HttpClientAdapter を差し替える）
///
/// `server.on('POST', '/auth/login', (r) => FakeResponse(200, {...}))` のように応答を決める。
/// 決めていない要求は 404 を返す
class FakeServer implements HttpClientAdapter {
  final _handlers = <String, FakeHandler>{};

  /// 受け取った要求（順番どおり）
  final requests = <RequestOptions>[];

  void on(String method, String path, FakeHandler handler) {
    _handlers['$method $path'] = handler;
  }

  /// 受け取った要求のうち、[path] あてのもの
  List<RequestOptions> sentTo(String path) =>
      requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 再送で同じ RequestOptions が使われるので、そのときのヘッダーを写して残す
    requests.add(options.copyWith(headers: Map.of(options.headers)));
    final handler = _handlers['${options.method} ${options.path}'];
    final response = handler == null
        ? const FakeResponse(404, {'code': 'NOT_FOUND'})
        : await handler(options);
    if (response.status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    // 画像などのバイト列はそのまま返す
    if (response.body case final Uint8List bytes) {
      return ResponseBody.fromBytes(bytes, response.status);
    }
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 偽のサーバーにつながる通信の部品
Dio fakeApiClient(
  FakeServer server,
  TokenStore tokens, {
  void Function()? onSessionExpired,
}) => createApiClient(
  tokens: tokens,
  baseUrl: 'http://test/api/v1',
  adapter: server,
  onSessionExpired: onSessionExpired,
);

/// ログインと新規登録の成功の応答
Map<String, Object> authBody({
  String userId = 'u1',
  String name = 'はる',
  String access = 'access-1',
  String refresh = 'refresh-1',
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'expiresIn': 900,
  'user': {'id': userId, 'email': 'haru@example.com', 'displayName': name},
};
