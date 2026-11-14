import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android のアプリのデータを OS のバックアップに出さない指定（NF-SC-10）
///
/// 指定が消えても画面の動きは変わらず気づきにくいので、設定のファイルを読んで確かめる。
/// テストはアプリのフォルダー（app）で動く
void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';

  /// <application ...> の開始タグだけを取り出す
  String applicationTag() {
    final manifest = File(manifestPath).readAsStringSync();
    return RegExp(r'<application\b[^>]*>').firstMatch(manifest)!.group(0)!;
  }

  test('UT-AB-01 Android 11 以前：application で allowBackup を false にしている', () {
    expect(applicationTag(), contains('android:allowBackup="false"'));
  });

  test('UT-AB-02 Android 12 以降：application が外し方の規則のファイルを指している', () {
    expect(
      applicationTag(),
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(File(rulesPath).existsSync(), isTrue);
  });

  test('UT-AB-03 規則：クラウドのバックアップと端末間の移行の両方で、すべての置き場所を外す', () {
    final rules = File(rulesPath).readAsStringSync();
    const domains = ['root', 'file', 'database', 'sharedpref', 'external'];
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(rules)?.group(1);
      expect(body, isNotNull, reason: '$section がない');
      // 取り込む指定（include）があると、それ以外が外れる意味に変わるので置かない
      expect(body, isNot(contains('<include')), reason: section);
      for (final domain in domains) {
        expect(
          body,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$section の $domain',
        );
      }
    }
  });
}
