import 'package:dio/dio.dart';

/// サーバーとの通信の失敗（API 設計書 9章のエラーの本文を読み取ったもの）
class ApiError implements Exception {
  const ApiError({this.status, this.code, this.requestId});

  /// 通信の失敗から作る。応答がない（つながらない・時間切れ）ときは [isOffline] になる
  factory ApiError.from(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiError();
    }
    final data = response.data;
    final body = data is Map ? data : const {};
    return ApiError(
      status: response.statusCode,
      code: body['code'] as String?,
      requestId: body['requestId'] as String?,
    );
  }

  /// HTTP の状態コード。応答がなければ null
  final int? status;

  /// エラーの種類（例：`UNAUTHORIZED`）
  final String? code;

  /// 問い合わせ番号（ログ設計書 4章）
  final String? requestId;

  /// サーバーにつながらなかった
  bool get isOffline => status == null;

  /// サーバーの異常。問い合わせ番号を画面に出す（F-LG-02）
  bool get isServerError => (status ?? 0) >= 500;

  /// 利用者向けの文。[known] に状態コードごとの文を渡し、なければ共通の文にする
  String message([Map<int, String> known = const {}]) {
    if (isOffline) {
      return 'サーバーにつながりません。通信の状態を確かめてください';
    }
    final text = known[status];
    if (text != null) {
      return text;
    }
    if (isServerError) {
      // 4xx は利用者が直せる誤りなので番号を出さない（ログ設計書 4章）
      return '問題が発生しました。時間をおいてやり直してください'
          '${requestId == null ? '' : '（問い合わせ番号：$requestId）'}';
    }
    return '入力内容を確かめてください';
  }

  @override
  String toString() => 'ApiError($status, $code, $requestId)';
}
