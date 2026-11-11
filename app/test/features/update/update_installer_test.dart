import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/update/data/update_installer.dart';
import 'package:meowscope/features/update/domain/app_release.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeServer server;
  late Directory root;
  late Directory dir;

  final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
  final sha = sha256.convert(bytes).toString();

  setUp(() async {
    server = FakeServer();
    root = await Directory.systemTemp.createTemp('meowscope-update-test');
    dir = Directory('${root.path}/updates');
  });
  tearDown(() => root.delete(recursive: true));

  AppRelease release({String? hash}) => AppRelease(
    version: '1.0.1',
    buildNumber: 3,
    sha256: hash ?? sha,
    sizeBytes: bytes.length,
  );

  /// 入れ方に渡されたファイル（渡されたときに中身があったか）
  final launched = <String, bool>{};

  DownloadingInstaller installer({
    String platform = 'android',
    Future<void> Function(File file)? launch,
  }) => DownloadingInstaller(
    api: fakeApiClient(server, MemoryTokenStore()),
    platform: platform,
    directory: () async => dir,
    launch:
        launch ??
        (file) async {
          launched[file.path.split(RegExp(r'[\\/]')).last] =
              file.existsSync() && file.lengthSync() == bytes.length;
        },
  );

  setUp(launched.clear);

  void serve(String platform) => server.on(
    'GET',
    '/app-releases/$platform/file',
    (_) => FakeResponse(200, bytes),
  );

  group('UT-UP-08 取ってきて照合し、入れ方に渡す（F-UP-02、BR-33）', () {
    test(
      'Android は APK を取り、SHA-256 が合えば渡す。進み具合は 1.0 まで。終わったらファイルを残さない',
      () async {
        serve('android');
        final progress = <double>[];
        await installer().install(release(), onProgress: progress.add);
        expect(launched, {'meowscope.apk': true});
        expect(progress.last, 1.0);
        expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
        expect(dir.existsSync(), isFalse);
      },
    );

    test('Windows は exe の名前で取り、windows のファイルを聞く', () async {
      serve('windows');
      await installer(platform: 'windows')
          .install(release(), onProgress: (_) {});
      expect(launched, {'meowscope-setup.exe': true});
      expect(server.sentTo('/app-releases/windows/file'), hasLength(1));
    });

    test('前の取りかけが残っていれば消してから取る', () async {
      serve('android');
      await Directory(dir.path).create(recursive: true);
      await File('${dir.path}/old.apk').writeAsString('old');
      await installer(
        launch: (file) async {
          expect(File('${dir.path}/old.apk').existsSync(), isFalse);
        },
      ).install(release(), onProgress: (_) {});
    });
  });

  group('UT-UP-09 異常系：失敗として扱い、ファイルを残さない（BR-33）', () {
    test('SHA-256 が合わなければ入れない', () async {
      serve('android');
      await expectLater(
        installer().install(release(hash: 'f' * 64), onProgress: (_) {}),
        throwsA(
          isA<UpdateFailed>().having(
            (e) => e.reason,
            'reason',
            'sha256_mismatch',
          ),
        ),
      );
      expect(launched, isEmpty);
      expect(dir.existsSync(), isFalse);
    });

    test('取ってこられない（つながらない・404）', () async {
      server.on(
        'GET',
        '/app-releases/android/file',
        (_) => const FakeResponse.offline(),
      );
      await expectLater(
        installer().install(release(), onProgress: (_) {}),
        throwsA(
          isA<UpdateFailed>().having((e) => e.reason, 'reason', 'download'),
        ),
      );
      server.on(
        'GET',
        '/app-releases/android/file',
        (_) => const FakeResponse(404, {'code': 'NOT_FOUND'}),
      );
      await expectLater(
        installer().install(release(), onProgress: (_) {}),
        throwsA(isA<UpdateFailed>()),
      );
      expect(launched, isEmpty);
      expect(dir.existsSync(), isFalse);
    });

    test('入れ方の画面を出せない', () async {
      serve('android');
      await expectLater(
        installer(
          launch: (_) async => throw PlatformException(code: 'launch_failed'),
        ).install(release(), onProgress: (_) {}),
        throwsA(
          isA<UpdateFailed>().having((e) => e.reason, 'reason', 'launch'),
        ),
      );
      expect(dir.existsSync(), isFalse);
    });
  });

  group('UT-UP-10 起動したときの片付け（BR-33）', () {
    test('残っている更新のファイルを消す。なければ何もしない', () async {
      await deleteUpdateFiles(dir);
      await Directory(dir.path).create(recursive: true);
      await File('${dir.path}/meowscope.apk').writeAsBytes(bytes);
      await deleteUpdateFiles(dir);
      expect(dir.existsSync(), isFalse);
    });
  });
}
