import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/domain/record_detail.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';
import 'package:meowscope/features/records/presentation/record_format.dart';

void main() {
  test('UT-RD-01 量の値を戻す：知っている値／空／知らない値（同値分割）', () {
    expect(RecordLevel.parse('much'), RecordLevel.much);
    expect(RecordLevel.parse(null), isNull);
    expect(RecordLevel.parse('huge'), isNull);
  });

  test('UT-RD-02 量と体重を入力する項目', () {
    final level = {for (final k in RecordKind.values) k: hasLevel(k.name)};
    expect(level, {
      RecordKind.food: true,
      RecordKind.water: true,
      RecordKind.medicine: false,
      RecordKind.urine: true,
      RecordKind.stool: true,
      RecordKind.vomit: true,
      RecordKind.weight: false,
      RecordKind.brushing: false,
    });
    expect(hasLevel(RecordKind.custom), isTrue);
    expect(RecordKind.values.where((k) => hasWeight(k.name)), [
      RecordKind.weight,
    ]);
    expect(hasWeight(RecordKind.custom), isFalse);
  });

  test('UT-RD-03 体重の境界値：0.09 と 30.01 は不可、0.1 と 30 は可', () {
    expect(validateWeight('0.09'), isNotNull);
    expect(validateWeight('0.1'), isNull);
    expect(validateWeight('30'), isNull);
    expect(validateWeight('30.01'), isNotNull);
  });

  test('UT-RD-04 体重の入力：空と空白は未入力、数字でなければ不可', () {
    expect(validateWeight(null), isNull);
    expect(validateWeight('  '), isNull);
    expect(validateWeight('四キロ'), '数字で入力してください');
  });

  test('UT-RD-05 日時の境界値：今と同じは可、1分先は不可', () {
    final now = DateTime(2026, 11, 3, 12);
    expect(validateRecordedAt(now, now), isNull);
    expect(
      validateRecordedAt(now.add(const Duration(minutes: 1)), now),
      isNotNull,
    );
  });

  test('UT-RD-06 日時と体重の表示の形', () {
    final d = DateTime(2026, 1, 2, 3, 4);
    expect(formatTime(d), '03:04');
    expect(formatDateTime(d), '01/02 03:04');
    expect(formatWeight(4.25), '4.25 kg');
  });
}
