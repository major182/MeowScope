import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';

void main() {
  group('RecordKind', () {
    test('UT-RC-01 標準の項目は8つで、ブラッシングを含む', () {
      expect(RecordKind.values.map((k) => k.label), [
        'ご飯',
        '水',
        '薬',
        'おしっこ',
        'うんち',
        '吐いた',
        '体重',
        'ブラッシング',
      ]);
    });
  });

  group('iconAsset', () {
    test('UT-RC-02 標準のイラストの名前なら場所を返す', () {
      expect(iconAsset('pee'), 'assets/icons/pee.png');
    });

    test('UT-RC-03 名前が空なら null を返す', () {
      expect(iconAsset(null), isNull);
    });

    test('UT-RC-04 用意していない名前なら null を返す', () {
      expect(iconAsset('unknown'), isNull);
    });
  });
}
