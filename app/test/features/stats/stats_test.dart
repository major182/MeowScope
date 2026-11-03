import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/stats/domain/stats.dart';

RecordEntry _entry(
  DateTime at, {
  String typeId = 't-food',
  String kind = 'food',
  double? kg,
}) => RecordEntry(
  id: '$at$typeId',
  recordedAt: at,
  catName: 'ミケ',
  typeName: kind,
  catId: 'c1',
  kind: kind,
  hasMemo: false,
  recordTypeId: typeId,
  valueNumber: kg,
);

void main() {
  test('UT-SS-01 週は今日までの7日、月は今日までの30日（古い順、最後が今日）', () {
    final today = DateTime(2026, 11, 2, 15);
    final week = periodDays(today, StatsPeriod.week);
    final month = periodDays(today, StatsPeriod.month);

    expect(week, hasLength(7));
    expect(week.first, DateTime(2026, 10, 27));
    expect(week.last, DateTime(2026, 11, 2));
    expect(month, hasLength(30));
    expect(month.first, DateTime(2026, 10, 4));
  });

  test('UT-SS-02 境界値：年をまたぐ期間', () {
    expect(
      periodDays(DateTime(2027, 1, 3), StatsPeriod.week).first,
      DateTime(2026, 12, 28),
    );
  });

  test('UT-SS-03 日ごとの回数：選んだ項目だけを数え、期間の外は数えない', () {
    final days = periodDays(DateTime(2026, 11, 2), StatsPeriod.week);
    final counts = dailyCounts(
      [
        _entry(DateTime(2026, 11, 2, 8)),
        _entry(DateTime(2026, 11, 2, 18)),
        _entry(DateTime(2026, 10, 27, 0)),
        _entry(DateTime(2026, 10, 26, 23, 59)),
        _entry(DateTime(2026, 11, 1, 9), typeId: 't-water', kind: 'water'),
      ],
      days,
      't-food',
    );

    expect(counts, [1, 0, 0, 0, 0, 0, 2]);
  });

  test('UT-SS-04 体重：数値のある体重の記録だけを古い順に返す', () {
    final points = weightSeries([
      _entry(DateTime(2026, 11, 2), typeId: 't-w', kind: 'weight', kg: 4.2),
      _entry(DateTime(2026, 11, 1), typeId: 't-w', kind: 'weight', kg: 4.1),
      _entry(DateTime(2026, 11, 1, 12), typeId: 't-w', kind: 'weight'),
      _entry(DateTime(2026, 11, 1, 13), kg: 9),
    ]);

    expect(points.map((p) => p.kg), [4.1, 4.2]);
  });

  test('UT-SS-05 体重の記録がなければ空', () {
    expect(weightSeries([_entry(DateTime(2026, 11, 2))]), isEmpty);
  });
}
