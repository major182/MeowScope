// E2E テストを動かす：dart run tool/e2e.dart windows または dart run tool/e2e.dart android [端末の ID]
//
// Android は、端末の ID を渡さなければエミュレーター（emulator-5554）で動かす。
// USB でつないだ実機の ID（adb devices で見える）を渡すと、adb reverse で実機の localhost:8080 を
// PC のサーバーにつなぎ、その実機で動かす（実機からは 10.0.2.2 で PC を呼べないため）
//
// 手元の Docker でサーバーを動かしておく（docker compose up -d）。Android はエミュレーターを起動しておく。
// 端末の DB とトークンの置き場は、テストの側でメモリーに差し替えるので、端末のデータは使わない
import 'dart:io';

import 'stay_on.dart';

/// 端末の種類ごとの、テストから見たサーバーの場所と flutter の端末の指定
const targets = {
  'windows': (device: 'windows', api: 'http://localhost:8080/api/v1'),
  // エミュレーターからは、PC の localhost を 10.0.2.2 で呼ぶ
  'android': (device: 'emulator-5554', api: 'http://10.0.2.2:8080/api/v1'),
};

Future<void> main(List<String> args) async {
  var target = args.isEmpty ? null : targets[args.first];
  if (target == null) {
    stderr.writeln('使い方：dart run tool/e2e.dart windows|android [端末の ID]');
    exit(64);
  }
  // Android の実機（USB）：端末の ID を渡されたら、その端末で動かし、サーバーには localhost でつなぐ
  if (args.first == 'android' &&
      args.length > 1 &&
      !args[1].startsWith('emulator-')) {
    final reverse = await Process.run('adb', [
      '-s',
      args[1],
      'reverse',
      'tcp:8080',
      'tcp:8080',
    ], runInShell: Platform.isWindows);
    if (reverse.exitCode != 0) {
      stderr.writeln('adb reverse に失敗しました：${reverse.stderr}');
      exit(1);
    }
    target = (device: args[1], api: 'http://localhost:8080/api/v1');
  } else if (args.length > 1) {
    target = (device: args[1], api: target.api);
  }
  if (!await _serverIsUp()) {
    stderr.writeln('サーバーが動いていません。docker compose up -d で起動してください');
    exit(1);
  }
  // USB の実機は、動かす間だけ画面を消さないようにする（途中で画面が消えると、画面が止まってテストが進まない）。
  // 終わったら、始める前の設定に戻す。利用者がいつも「画面を消さない」にしている端末では、オンのまま残す（#316）
  final usb = args.first == 'android' && !target.device.startsWith('emulator-');
  String? stayOnBefore;
  if (usb) {
    stayOnBefore = await _stayOnSetting(target.device);
    await _adb(target.device, ['shell', 'svc', 'power', 'stayon', 'usb']);
    await _adb(target.device, ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP']);
  }
  // テストのファイルを1つずつ動かす。Windows のアプリは二重に起動しない作り（#173）なので、
  // 前のファイルのテスト用アプリが終わりきる前に次を起動すると、起動できずに失敗する
  final files =
      Directory('integration_test')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((path) => path.endsWith('_test.dart'))
          .toList()
        ..sort();
  var failed = false;
  try {
    for (final file in files) {
      if (Platform.isWindows && target.device == 'windows') {
        await _waitAppExit();
      }
      final process = await Process.start(
        'flutter',
        [
          'test',
          file,
          '-d',
          target.device,
          '--dart-define=API_BASE_URL=${target.api}',
        ],
        runInShell: Platform.isWindows,
        mode: ProcessStartMode.inheritStdio,
      );
      if (await process.exitCode != 0) {
        failed = true;
      }
    }
  } finally {
    // 読めなかったときは変えない（利用者の設定を崩さないため）
    if (stayOnBefore != null) {
      await _adb(target.device, [
        'shell',
        'settings',
        'put',
        'global',
        'stay_on_while_plugged_in',
        stayOnBefore,
      ]);
    }
  }
  exit(failed ? 1 : 0);
}

/// 端末の「画面を消さない（充電中にスリープしない）」の設定の値。0 はオフ、1〜15 はどの充電のときにオンか。
/// 読めなければ null
Future<String?> _stayOnSetting(String device) async {
  final r = await Process.run('adb', [
    '-s',
    device,
    'shell',
    'settings',
    'get',
    'global',
    'stay_on_while_plugged_in',
  ], runInShell: Platform.isWindows);
  return parseStayOn(r.exitCode, r.stdout.toString());
}

/// adb を、決めた端末に向けて動かす
Future<void> _adb(String device, List<String> args) =>
    Process.run('adb', ['-s', device, ...args], runInShell: Platform.isWindows);

/// Windows のテスト用アプリ（meowscope.exe）が終わるまで待つ（最大30秒）
Future<void> _waitAppExit() async {
  for (var i = 0; i < 30; i++) {
    final r = await Process.run('tasklist', [
      '/FI',
      'IMAGENAME eq meowscope.exe',
    ]);
    if (!r.stdout.toString().contains('meowscope.exe')) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

/// PC から見たサーバーの死活監視が UP か
Future<bool> _serverIsUp() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(
      Uri.parse('http://localhost:8080/actuator/health'),
    );
    final response = await request.close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    return response.statusCode == 200 && body.contains('UP');
  } on Exception {
    return false;
  } finally {
    client.close();
  }
}
