import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';

/// すべての単体テストの前に動く、テストの道具の共通の設定（flutter_test の仕組み）
///
/// 今の版（package_info_plus）は OS に問い合わせて読むが、テストの中には OS がなく、
/// 問い合わせが返らずに止まる。パッケージが用意しているテスト用の値で答えさせる
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PackageInfo.setMockInitialValues(
    appName: 'MeowScope',
    packageName: 'com.meowscope.meowscope',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await testMain();
}
