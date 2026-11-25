import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/stats/domain/detail_stats.dart';

/// くわしい統計の計算（S-31。F-ST-04〜06）
void main() {
  final today = DateTime(2026, 11, 25, 15);

  RecordEntry entry(
    String id,
    String catId,
    String typeId,
    DateTime at, {
    double? kg,
  }) => RecordEntry(
    id: id,
    recordedAt: at,
    catName: catId,
    typeName: typeId,
    catId: catId,
    kind: typeId == 'w' ? 'weight' : 'food',
    hasMemo: false,
    recordTypeId: typeId,
    valueNumber: kg,
  );

  group('UT-DS-01 期間（F-ST-04）', () {
    test('境界値：週は7日・月は30日・年は365日で、最後が今日', () {
      for (final (p, n) in [
        (DetailPeriod.week, 7),
        (DetailPeriod.month, 30),
        (DetailPeriod.year, 365),
      ]) {
        final days = detailDays(p, today);
        expect(days, hasLength(n));
        expect(days.last, DateTime(2026, 11, 25));
      }
      expect(
        detailDays(DetailPeriod.week, today).first,
        DateTime(2026, 11, 19),
      );
    });

    test('指定は両端の日を含む。1日だけ・月をまたぐ。両端がそろわない・逆なら空', () {
      expect(
        detailDays(
          DetailPeriod.custom,
          today,
          from: DateTime(2026, 10, 30, 9),
          to: DateTime(2026, 11, 2),
        ),
        [
          DateTime(2026, 10, 30),
          DateTime(2026, 10, 31),
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 2),
        ],
      );
      final one = DateTime(2026, 11, 1);
      expect(detailDays(DetailPeriod.custom, today, from: one, to: one), [one]);
      expect(detailDays(DetailPeriod.custom, today, from: one), isEmpty);
      expect(
        detailDays(
          DetailPeriod.custom,
          today,
          from: one,
          to: DateTime(2026, 10, 31),
        ),
        isEmpty,
      );
    });
  });

  group('UT-DS-02 重ねる線（F-ST-05・06）', () {
    final days = [
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 3),
    ];
    final entries = [
      entry('1', 'mike', 'food', DateTime(2026, 11, 1, 8)),
      entry('2', 'mike', 'food', DateTime(2026, 11, 1, 19)),
      entry('3', 'tama', 'food', DateTime(2026, 11, 3, 8)),
      entry('4', 'mike', 'w', DateTime(2026, 11, 2, 8), kg: 4.0),
      entry('5', 'mike', 'w', DateTime(2026, 11, 2, 20), kg: 4.2),
      // 期間の外は数えない
      entry('6', 'mike', 'food', DateTime(2026, 10, 31, 8)),
    ];

    test('猫と項目の組ごとに線を作る（猫の順・項目の順）', () {
      final s = buildSeries(
        entries: entries,
        days: days,
        catIds: ['mike', 'tama'],
        typeIds: ['food', 'w'],
        weightTypeIds: {'w'},
      );
      expect(
        [for (final x in s) (x.key.catId, x.key.typeId, x.weight)],
        [
          ('mike', 'food', false),
          ('mike', 'w', true),
          ('tama', 'food', false),
          ('tama', 'w', true),
        ],
      );
      // 回数は記録のない日も 0 の点を打つ
      expect([for (final p in s[0].points) p.value], [2, 0, 0]);
      expect([for (final p in s[2].points) p.value], [0, 0, 1]);
      // 体重はその日の最後の値。記録のない日は点を打たない
      expect([for (final p in s[1].points) (p.dayIndex, p.value)], [(1, 4.2)]);
      expect(s[3].points, isEmpty);
    });
  });

  group('UT-DS-03 体重の目盛りの換算（F-ST-06）', () {
    test('体重の範囲を回数の目盛りの 0〜上端に引き伸ばし、戻せる', () {
      final scale = WeightScale(min: 4, max: 5, countMax: 8);
      expect(scale.toLeft(4), 0);
      expect(scale.toLeft(5), 8);
      expect(scale.toLeft(4.5), 4);
      expect(scale.toKg(4), 4.5);
    });

    test('境界値：体重が1つの値だけなら、上下に 0.5kg の幅を取る', () {
      final scale = WeightScale(min: 4.2, max: 4.2, countMax: 4);
      expect(scale.min, closeTo(3.7, 1e-9));
      expect(scale.max, closeTo(4.7, 1e-9));
      expect(scale.toLeft(4.2), closeTo(2, 1e-9));
    });
  });
}
