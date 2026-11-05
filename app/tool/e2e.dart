// E2E テストを動かす：dart run tool/e2e.dart windows または dart run tool/e2e.dart android
//
// 手元の Docker でサーバーを動かしておく（docker compose up -d）。Android はエミュレーターを起動しておく。
// 端末の DB とトークンの置き場は、テストの側でメモリーに差し替えるので、端末のデータは使わない
import 'dart:io';

/// 端末の種類ごとの、テストから見たサーバーの場所と flutter の端末の指定
const targets = {
  'windows': (device: 'windows', api: 'http://localhost:8080/api/v1'),
  // エミュレーターからは、PC の localhost を 10.0.2.2 で呼ぶ
  'android': (device: 'emulator-5554', api: 'http://10.0.2.2:8080/api/v1'),
};

Future<void> main(List<String> args) async {
  final target = args.isEmpty ? null : targets[args.first];
  if (target == null) {
    stderr.writeln('使い方：dart run tool/e2e.dart windows|android');
    exit(64);
  }
  if (!await _serverIsUp()) {
    stderr.writeln('サーバーが動いていません。docker compose up -d で起動してください');
    exit(1);
  }
  final process = await Process.start(
    'flutter',
    [
      'test',
      'integration_test',
      '-d',
      target.device,
      '--dart-define=API_BASE_URL=${target.api}',
    ],
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await process.exitCode);
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
