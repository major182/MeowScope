// アプリのチェックを1つのコマンドにまとめる：dart run tool/check.dart
// --all を付けるとサーバーの ./gradlew check も実行する。CI も同じコマンドを使う
import 'dart:io';

/// NF-MT-01 のしきい値（行カバレッジ）
const minimumCoverage = 80.0;

Future<void> run(String command, List<String> args, {String? dir}) async {
  stdout.writeln('> $command ${args.join(' ')}');
  final process = await Process.start(
    command,
    args,
    workingDirectory: dir,
    // Windows では flutter.bat を探すためにシェルを通す
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    exit(code);
  }
}

/// lcov.info の LF（対象の行）と LH（通った行）から割合を求める
double lineCoverage(String lcov) {
  var found = 0;
  var hit = 0;
  for (final line in lcov.split('\n')) {
    if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3).trim());
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3).trim());
    }
  }
  return found == 0 ? 0 : hit * 100 / found;
}

Future<void> main(List<String> args) async {
  await run('dart', ['format', '--output=none', '--set-exit-if-changed', '.']);
  await run('flutter', ['analyze', '--fatal-infos']);
  await run('flutter', ['test', '--coverage']);

  final coverage = lineCoverage(File('coverage/lcov.info').readAsStringSync());
  stdout.writeln('行カバレッジ: ${coverage.toStringAsFixed(1)}%');
  if (coverage < minimumCoverage) {
    stderr.writeln('カバレッジが $minimumCoverage% を下回りました');
    exit(1);
  }

  if (args.contains('--all')) {
    await run(Platform.isWindows ? r'.\gradlew.bat' : './gradlew', [
      'check',
    ], dir: '../server');
  }
}
