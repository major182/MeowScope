import 'package:dio/dio.dart';

import '../../features/auth/data/token_store.dart';

/// サーバーの API の入口（API 設計書 1章）。ビルドのときに `--dart-define=API_BASE_URL=...` で変えられる
///
/// Android のエミュレーターから手元の PC のサーバーへつなぐときは `http://10.0.2.2:8080/api/v1` を渡す
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

/// 認証の要らない API に付ける印。トークンを付けず、401 でも更新を試さない
const noAuth = 'noAuth';

/// トークンを付けて API を呼ぶ通信の部品を作る（技術選定書 3章：dio のインターセプター）
///
/// - 要求のたびに、保管場所のアクセストークンを `Authorization` に付ける
/// - 401 が返ったら、更新トークンで1回だけ交換して、元の要求をやり直す
/// - 交換にも失敗したら、トークンを消して [onSessionExpired] を呼ぶ。端末での記録は続けられる（API 設計書 2章）
///
/// テストでは [adapter] に偽のサーバーを渡す
Dio createApiClient({
  required TokenStore tokens,
  String baseUrl = apiBaseUrl,
  HttpClientAdapter? adapter,
  void Function()? onSessionExpired,
}) {
  BaseOptions options() => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  );
  final dio = Dio(options());
  // 更新とやり直しの要求は、この部品自身を通さない。順番待ちの部品の中から同じ部品を通すと、
  // やり直しが 401 になったときに自分の処理の終わりを待って止まってしまう
  final refresher = Dio(options());
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refresher.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    // 順番に処理する版を使い、同時に 401 が来ても更新を1回にまとめる
    QueuedInterceptorsWrapper(
      onRequest: (request, handler) async {
        if (request.extra[noAuth] != true) {
          final saved = await tokens.read();
          if (saved != null) {
            request.headers['Authorization'] = 'Bearer ${saved.accessToken}';
          }
        }
        handler.next(request);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.extra[noAuth] == true ||
            request.extra['retried'] == true) {
          return handler.next(error);
        }
        final saved = await tokens.read();
        if (saved == null) {
          return handler.next(error);
        }
        // 別の要求がすでに交換していれば、新しいトークンでやり直すだけにする
        final sent = request.headers['Authorization'];
        var current = saved;
        if (sent == 'Bearer ${saved.accessToken}') {
          try {
            final response = await refresher.post<Map<String, dynamic>>(
              '/auth/refresh',
              data: {'refreshToken': saved.refreshToken},
            );
            current = AuthTokens(
              accessToken: response.data!['accessToken'] as String,
              refreshToken: response.data!['refreshToken'] as String,
            );
            await tokens.save(current);
          } on DioException catch (e) {
            if (e.response?.statusCode == 401) {
              // 期限切れ・使い回しの検知。もう一度ログインしてもらう
              await tokens.clear();
              onSessionExpired?.call();
            }
            return handler.next(error);
          }
        }
        request.headers['Authorization'] = 'Bearer ${current.accessToken}';
        request.extra['retried'] = true;
        try {
          handler.resolve(await refresher.fetch(request));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ),
  );
  return dio;
}
