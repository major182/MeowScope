import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_release.dart';

/// 取ってこられない・SHA-256 が合わない・入れられないとき（BR-33）
class UpdateFailed implements Exception {
  const UpdateFailed(this.reason);

  /// ログに残す理由（種類だけ。URL やトークンは入れない）
  final String reason;

  @override
  String toString() => 'UpdateFailed($reason)';
}

/// 新しい版を取ってきて照合し、入れる（F-UP-02）
abstract class UpdateInstaller {
  /// [onProgress] に 0.0〜1.0 の進み具合を渡す。失敗したら [UpdateFailed] を投げ、取りかけのファイルを残さない
  Future<void> install(
    AppRelease release, {
    required void Function(double progress) onProgress,
  });
}

/// 端末に合った部品を作る。取得と入れ方は次の作業（Ver.1.1 No.3）で作るまで、失敗として扱う
UpdateInstaller createUpdateInstaller(Ref ref) => const _NotReadyInstaller();

class _NotReadyInstaller implements UpdateInstaller {
  const _NotReadyInstaller();

  @override
  Future<void> install(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async => throw const UpdateFailed('not_ready');
}
