import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/providers.dart';
import 'data/update_installer.dart';
import 'data/update_repository.dart';
import 'domain/app_release.dart';

/// 端末に入っている今の版（F-UP-03）。テストでは決めた版に差し替える
final installedVersionProvider = FutureProvider<InstalledVersion>((ref) async {
  // Android は versionName と versionCode、Windows は exe のファイルの版から読む（pubspec.yaml の version）
  final info = await PackageInfo.fromPlatform();
  return InstalledVersion(
    version: info.version,
    buildNumber: int.tryParse(info.buildNumber) ?? 0,
  );
});

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => UpdateRepository(
    ref.watch(apiClientProvider),
    () => ref.read(installedVersionProvider.future),
    platform: defaultTargetPlatform == TargetPlatform.windows
        ? 'windows'
        : 'android',
  ),
);

/// 新しい版を取ってきて入れる部品。テストでは偽物に差し替える
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => createUpdateInstaller(ref),
);

/// 更新のお知らせ（S-51）を出す時機を持つ。値があれば、[UpdateRunner] がダイアログを出す
///
/// 起動したとき・設定の「更新を確かめる」・「5分後に知らせる」の5分後に値を入れる（BR-33）
final updatePromptProvider =
    NotifierProvider<UpdatePromptController, UpdateAvailable?>(
      UpdatePromptController.new,
    );

class UpdatePromptController extends Notifier<UpdateAvailable?> {
  /// 「5分後に知らせる」の待ち時間（BR-33）
  static const remindAfter = Duration(minutes: 5);

  Timer? _reminder;

  @override
  UpdateAvailable? build() {
    ref.onDispose(() => _reminder?.cancel());
    return null;
  }

  /// サーバーに聞き、新しい版があればお知らせを出す
  Future<UpdateCheck> check() async {
    final result = await ref.read(updateRepositoryProvider).check();
    if (result is UpdateAvailable) {
      _reminder?.cancel();
      state = result;
    }
    return result;
  }

  /// お知らせを出したので、値を空に戻す（同じお知らせを二度出さない）
  void shown() => state = null;

  /// 5分後にもう一度出す。アプリはそのまま使える
  void remindLater(UpdateAvailable update) {
    _reminder?.cancel();
    _reminder = Timer(remindAfter, () => state = update);
  }
}
