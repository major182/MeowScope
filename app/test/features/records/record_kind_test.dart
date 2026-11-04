import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/domain/custom_type.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';

void main() {
  group('RecordKind', () {
    test('UT-RC-01 標準の項目は8つで、ブラシを含む', () {
      expect(RecordKind.values.map((k) => k.label), [
        'ご飯',
        '水',
        '薬',
        'おしっこ',
        'うんち',
        '吐いた',
        '体重',
        'ブラシ',
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

    test('UT-RC-15 独自の項目のイラストの名前なら場所を返す', () {
      expect(iconAsset('custom_teeth'), 'assets/icons/custom_teeth.png');
    });
  });

  test('UT-RC-16 使うイラストのファイルがすべてある（標準・カレンダー用・独自・メモ）', () {
    final paths = {
      for (final k in RecordKind.values) ...[
        iconAsset(k.icon)!,
        calendarAsset(k.name, k.icon),
      ],
      for (final i in CustomIcon.values) iconAsset(i.value)!,
      fallbackIconAsset,
      memoAsset,
    };
    expect(paths, hasLength(8 * 2 + 6 + 1));
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });
}
