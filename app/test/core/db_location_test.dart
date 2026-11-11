import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';

// DB を置くフォルダー（デプロイ設計書 6.3：開発版と配布版の保存先を分ける）
void main() {
  test('UT-DS-01 Windows では、アプリ名で分かれる保存先（アプリのサポートのフォルダー）に置く', () {
    expect(databaseDirectoryFor(isWindows: true), isNotNull);
  });

  test('UT-DS-02 Windows 以外（Android）は drift の既定のまま（アプリの ID で分かれる）', () {
    expect(databaseDirectoryFor(isWindows: false), isNull);
  });
}
