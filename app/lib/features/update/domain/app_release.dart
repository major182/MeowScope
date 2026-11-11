/// サーバーに置いてある、いちばん新しい版（API 設計書 10章）
class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.sha256,
    required this.sizeBytes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    version: json['version'] as String,
    buildNumber: json['buildNumber'] as int,
    sha256: json['sha256'] as String,
    sizeBytes: json['sizeBytes'] as int,
  );

  /// 画面に出す版（例：1.0.1）
  final String version;

  /// 新しいかどうかを比べる番号（BR-34）
  final int buildNumber;

  /// ファイルの SHA-256（小文字の 16 進 64 文字）。取ってきたファイルと照合する（BR-33）
  final String sha256;

  final int sizeBytes;
}

/// 端末に入っている今の版（pubspec.yaml の version。例：1.0.0+1）
class InstalledVersion {
  const InstalledVersion({required this.version, required this.buildNumber});

  /// 画面に出す版。ビルド番号は出さない（画面設計書 S-01）
  final String version;

  final int buildNumber;

  /// [release] が今の版より新しいか。版の文字ではなくビルド番号で比べる（BR-34）
  bool isOlderThan(AppRelease release) => release.buildNumber > buildNumber;
}

/// 更新を確かめた結果
sealed class UpdateCheck {
  const UpdateCheck();
}

/// 新しい版がある
class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.release, this.installed);

  final AppRelease release;
  final InstalledVersion installed;
}

/// 今の版がいちばん新しい（サーバーに版が置かれていないときも含む）
class UpToDate extends UpdateCheck {
  const UpToDate();
}

/// 通信できない・ログインしていないなどで確かめられなかった
class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed();
}
