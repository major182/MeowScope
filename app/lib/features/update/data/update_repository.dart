import 'package:dio/dio.dart';

import '../domain/app_release.dart';

/// サーバーに新しい版を聞く（F-UP-01、API 設計書 10章）
class UpdateRepository {
  UpdateRepository(this._api, this._installed, {required this.platform});

  final Dio _api;
  final Future<InstalledVersion> Function() _installed;

  /// `android` か `windows`。開発版は開発用のサーバーに聞くので、名前は配布版と同じ
  final String platform;

  /// 新しい版があるかを確かめる。失敗してもアプリは使えるよう、例外にせず結果で返す（BR-33）
  Future<UpdateCheck> check() async {
    try {
      final installed = await _installed();
      final response = await _api.get<Map<String, dynamic>>(
        '/app-releases/$platform/latest',
      );
      final release = AppRelease.fromJson(response.data!);
      return installed.isOlderThan(release)
          ? UpdateAvailable(release, installed)
          : const UpToDate();
    } on DioException catch (e) {
      // 版が置かれていなければ、今の版のままでよい
      return e.response?.statusCode == 404
          ? const UpToDate()
          : const UpdateCheckFailed();
    } on TypeError {
      // 版の情報の形が違う（サーバーの置き方の誤り）
      return const UpdateCheckFailed();
    } on Exception {
      // 今の版が読めないなど
      return const UpdateCheckFailed();
    }
  }
}
