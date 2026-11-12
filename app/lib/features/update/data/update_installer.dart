import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers.dart';
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

/// 更新のファイルを置くフォルダー。開発版と配布版で分かれる場所（アプリ用のフォルダー）の下に置く
Future<Directory> updateDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/updates');

/// 前に使った更新のファイルを消す（BR-33：入れた後の次の起動で消す）。起動のたびに呼ぶ
Future<void> deleteUpdateFiles(Directory dir) async {
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

/// 取ってきたファイルで、端末に新しい版を入れる。Android は入れ方の画面から戻ると返り、Windows はアプリを閉じる
typedef LaunchInstaller = Future<void> Function(File file);

/// サーバーから取ってきて SHA-256 を照合し、端末の入れ方に渡す（BR-33、画面設計書 S-51）
class DownloadingInstaller implements UpdateInstaller {
  DownloadingInstaller({
    required this.api,
    required this.platform,
    required this.directory,
    required this.launch,
  });

  final Dio api;
  final String platform;
  final Future<Directory> Function() directory;
  final LaunchInstaller launch;

  /// 置くファイルの名前。Windows は exe の拡張子がないと動かせない
  String get _fileName =>
      platform == 'windows' ? 'meowscope-setup.exe' : 'meowscope.apk';

  @override
  Future<void> install(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    final dir = await directory();
    // 前の取りかけが残っていれば消してから始める
    await deleteUpdateFiles(dir);
    await dir.create(recursive: true);
    final file = File('${dir.path}/$_fileName');
    try {
      await _download(release, file, onProgress);
      if (await _sha256(file) != release.sha256) {
        throw const UpdateFailed('sha256_mismatch');
      }
      await launch(file);
    } on UpdateFailed {
      rethrow;
    } on DioException {
      throw const UpdateFailed('download');
    } on PlatformException {
      throw const UpdateFailed('launch');
    } on FileSystemException {
      throw const UpdateFailed('file');
    } finally {
      // Android で入れ方の画面を取りやめた・失敗したときも、ファイルを残さない（BR-33）
      // 入れ終わったときはアプリが閉じるので、ここには来ない（次の起動で消す）
      await deleteUpdateFiles(dir).catchError((Object _) {});
    }
  }

  Future<void> _download(
    AppRelease release,
    File file,
    void Function(double progress) onProgress,
  ) async {
    await api.download(
      '/app-releases/$platform/file',
      file.path,
      // 数十 MB を取るので、途中で止まったと判断するまでの時間を長めにする
      options: Options(receiveTimeout: const Duration(minutes: 2)),
      onReceiveProgress: (received, total) {
        final all = total > 0 ? total : release.sizeBytes;
        if (all > 0) onProgress((received / all).clamp(0.0, 1.0));
      },
    );
  }

  /// 数十 MB のファイルを、メモリに一度に読まずに少しずつ計算する
  static Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}

/// Android：OS のインストールの画面を出す（Kotlin の MainActivity）。利用者が戻ってきたら返る
///
/// 「インストール」を押すと、OS が古いアプリを閉じて入れ、「開く」で開き直せる。
/// 取りやめたときは、このアプリの画面に戻ってくるので、そこでファイルを消す
Future<void> launchAndroidInstaller(File file) async {
  const channel = MethodChannel('com.meowscope/update');
  Future<String?> openAndWait() async {
    final resumed = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!resumed.isCompleted) resumed.complete();
      },
    );
    try {
      final status = await channel.invokeMethod<String>('installApk', {
        'path': file.path,
      });
      await resumed.future;
      return status;
    } finally {
      listener.dispose();
    }
  }

  // 初めてのときは許可の画面が先に出る。許可して戻ってきたら、インストールの画面を出す
  // （許可しなかったときは、もう一度許可の画面が出るので、そこで戻れば取りやめになる）
  if (await openAndWait() == 'needs_permission') {
    await openAndWait();
  }
}

/// Windows：インストーラーを確認なしのモードで動かし、アプリを閉じる。
/// インストーラーが入れ終わった後にアプリを開き直す（meowscope.iss の [Run]）
Future<void> launchWindowsInstaller(
  File file, {
  required Future<void> Function() closeDatabase,
}) async {
  await Process.start(file.path, const [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    // 閉じきっていないアプリを、インストーラーが閉じてから入れる
    '/CLOSEAPPLICATIONS',
  ], mode: ProcessStartMode.detached);
  await closeThenExit(closeDatabase, exit);
}

/// 端末の DB を閉じてから、アプリを終える。閉じられなくても終える（更新を止めない）
///
/// SQLite は途中で終えても壊れない作りだが、書きかけを確定させてから終えるほうが丁寧
Future<void> closeThenExit(
  Future<void> Function() closeDatabase,
  void Function(int code) exitApp,
) async {
  try {
    await closeDatabase();
  } on Object {
    // 閉じられなくても更新は続ける
  }
  exitApp(0);
}

/// 端末に合った部品を作る
UpdateInstaller createUpdateInstaller(Ref ref) {
  final windows = defaultTargetPlatform == TargetPlatform.windows;
  return DownloadingInstaller(
    api: ref.watch(apiClientProvider),
    platform: windows ? 'windows' : 'android',
    directory: updateDirectory,
    launch: windows
        ? (file) => launchWindowsInstaller(
            file,
            closeDatabase: () => ref.read(databaseProvider).close(),
          )
        : launchAndroidInstaller,
  );
}
