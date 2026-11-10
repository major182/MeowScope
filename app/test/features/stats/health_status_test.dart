import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/notifications/domain/anomaly.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/stats/domain/health_status.dart';

const _cat = AnomalyCat(id: 'c1', name: 'ミケ');
final _now = DateTime(2026, 11, 10, 10);
final _yesterday = DateTime(2026, 11, 9);

/// [day] の [hour] 時の記録を [n] 件
List<AnomalyRecord> _records(
  String kind,
  DateTime day,
  int n, {
  double? kg,
  String catId = 'c1',
}) => [
  for (var i = 0; i < n; i++)
    AnomalyRecord(
      catId: catId,
      kind: kind,
      recordedAt: DateTime(day.year, day.month, day.day, 8 + i),
      valueNumber: kg,
    ),
];

/// [day] より前の [days] 日、毎日ご飯を [perDay] 回
List<AnomalyRecord> _usual(DateTime day, int days, {int perDay = 3}) => [
  for (var i = 1; i <= days; i++)
    ..._records('food', DateTime(day.year, day.month, day.day - i), perDay),
];

HealthItem _item(HealthStatus s, String kind) =>
    s.items.firstWhere((i) => i.kind == kind);

HealthStatus _status(
  List<AnomalyRecord> records, {
  DateTime? day,
  AnomalyMethod method = AnomalyMethod.statistical,
  AnomalyCat cat = _cat,
}) => healthStatus(
  cat: cat,
  records: records,
  method: method,
  day: day ?? _yesterday,
  now: _now,
);

void main() {
  group('UT-HS-01 ふだんの回数の範囲（BR-31）', () {
    test('いつも同じ回数なら、その回数だけ。0回ばかりなら0回', () {
      expect(usualCountRange(List.filled(7, 3)), (min: 3, max: 3));
      expect(usualCountRange(List.filled(7, 0)), (min: 0, max: 0));
    });

    test('平均3・標準偏差1なら 1〜5回（±2標準偏差の内側の整数）', () {
      expect(usualCountRange([2, 4, 2, 4, 2, 4, 2, 4]), (min: 1, max: 5));
    });

    test('下限は0回より下にしない', () {
      expect(usualCountRange([0, 0, 0, 0, 0, 0, 5]).min, 0);
    });

    test('整数の範囲の外と、元の判定（±2標準偏差の外、かつ平均と1回以上違う）が、どの回数でも一致する', () {
      final random = Random(1);
      for (var n = 0; n < 500; n++) {
        final counts = [
          for (var i = 0; i < 7 + random.nextInt(22); i++) random.nextInt(8),
        ];
        final mean = counts.reduce((a, b) => a + b) / counts.length;
        final sd = sqrt(
          counts.map((c) => pow(c - mean, 2)).reduce((a, b) => a + b) /
              counts.length,
        );
        final range = usualCountRange(counts);
        for (var y = 0; y <= 15; y++) {
          expect(
            y < range.min!,
            y < mean - 2 * sd && mean - y >= 1,
            reason: '$counts の $y 回（少なすぎ）',
          );
          expect(
            y > range.max!,
            y > mean + 2 * sd && y - mean >= 1,
            reason: '$counts の $y 回（多すぎ）',
          );
        }
      }
    });
  });

  group('UT-HS-02 統計の方式：その日の回数と範囲を並べ、外れ値に印を付ける', () {
    test('ふだん3回のご飯がきのう1回なら少なめ。記録のない項目は0回で、ふだん0回なら範囲内', () {
      final s = _status([
        ..._usual(_yesterday, 28),
        ..._records('food', _yesterday, 1),
      ]);
      expect(s.daysLeft, 0);
      expect(s.recorded, isTrue);
      final food = _item(s, 'food');
      expect((food.value, food.min, food.max), (1, 3, 3));
      expect(food.outlier, AnomalyDirection.low);
      final water = _item(s, 'water');
      expect((water.value, water.min, water.max), (0, 0, 0));
      expect(water.outlier, isNull);
      // 項目は記録項目の並び順。薬・ブラシは出さない
      expect(
        [for (final i in s.items) i.kind],
        [...anomalyCountKinds, 'weight'],
      );
    });

    test('多すぎは多めの印。ほかの猫の記録は数えない', () {
      final s = _status([
        ..._usual(_yesterday, 28),
        ..._records('food', _yesterday, 5),
        ..._records('food', _yesterday, 9, catId: 'c2'),
      ]);
      expect(_item(s, 'food').value, 5);
      expect(_item(s, 'food').outlier, AnomalyDirection.high);
    });
  });

  group('UT-HS-03 記録が7日分に満たない間は判定しない（境界値）', () {
    test('6日分ならあと1日', () {
      final s = _status(_usual(_yesterday, 6));
      expect(s.daysLeft, 1);
      expect(s.items, isEmpty);
    });

    test('7日分なら判定する', () {
      expect(_status(_usual(_yesterday, 7)).daysLeft, 0);
    });

    test('28日より前の記録はふだんに入れない', () {
      final old = _usual(DateTime(2026, 10, 12), 7);
      expect(_status(old).daysLeft, minRecordDays);
    });
  });

  group('UT-HS-04 今日と、記録のない日は、少なすぎを判定しない', () {
    test('今日：下限なしで多すぎだけを見る。ふだんは前日より前の28日', () {
      final today = DateTime(2026, 11, 10);
      final s = _status([
        ..._usual(_yesterday, 28),
        // 前日の多い記録はふだんに入れない
        ..._records('food', _yesterday, 9),
        ..._records('food', today, 0),
        ..._records('water', today, 1),
      ], day: today);
      final food = _item(s, 'food');
      expect((food.min, food.max, food.outlier), (null, 3, null));
      expect(_item(s, 'water').outlier, AnomalyDirection.high);
    });

    test('記録のない日：recorded が false で、下限を出さない', () {
      final s = _status(_usual(_yesterday, 28));
      expect(s.recorded, isFalse);
      final food = _item(s, 'food');
      expect((food.value, food.min, food.outlier), (0, null, null));
    });
  });

  group('UT-HS-05 しきい値の方式（BR-20）', () {
    const cat = AnomalyCat(
      id: 'c1',
      name: 'ミケ',
      thresholds: '{"food":{"min":2,"max":4},"weight":{"percent":10}}',
    );

    test('決めた下限・上限で判定する。決めていない項目はしきい値なし。7日分なくても判定する', () {
      final s = _status(
        _records('food', _yesterday, 1),
        method: AnomalyMethod.threshold,
        cat: cat,
      );
      expect(s.daysLeft, 0);
      final food = _item(s, 'food');
      expect((food.min, food.max, food.outlier), (2, 4, AnomalyDirection.low));
      expect(_item(s, 'water').hasRule, isFalse);
      expect(_item(s, 'water').outlier, isNull);
    });

    test('体重は決めた割合（10%）で判定する', () {
      final s = _status(
        [
          ..._records('weight', DateTime(2026, 11, 1), 1, kg: 4),
          ..._records('weight', _yesterday, 1, kg: 4.3),
        ],
        method: AnomalyMethod.threshold,
        cat: cat,
      );
      final w = _item(s, 'weight');
      expect(w.outlier, isNull);
      expect(w.min, closeTo(3.6, 1e-9));
      expect(w.max, closeTo(4.4, 1e-9));
    });
  });

  group('UT-HS-06 体重', () {
    final usual = _usual(_yesterday, 28);

    test('±5% を超えたら外れ値。ちょうど 5% は範囲内（境界値）', () {
      List<AnomalyRecord> weights(double kg) => [
        ...usual,
        ..._records('weight', DateTime(2026, 11, 1), 1, kg: 4),
        ..._records('weight', _yesterday, 1, kg: kg),
      ];
      final at5 = _item(_status(weights(4.2)), 'weight');
      expect(at5.outlier, isNull);
      expect((at5.value, at5.weightDay), (4.2, null));
      expect(at5.min, closeTo(3.8, 1e-9));
      expect(at5.max, closeTo(4.2, 1e-9));
      expect(
        _item(_status(weights(4.3)), 'weight').outlier,
        AnomalyDirection.high,
      );
      expect(
        _item(_status(weights(3.7)), 'weight').outlier,
        AnomalyDirection.low,
      );
    });

    test('その日に記録がなければ、それより前の最新の記録を日付つきで出す。後の日の記録は使わない', () {
      final s = _status([
        ...usual,
        ..._records('weight', DateTime(2026, 11, 1), 1, kg: 4),
        ..._records('weight', DateTime(2026, 11, 5), 1, kg: 4.1),
        ..._records('weight', DateTime(2026, 11, 10), 1, kg: 9),
      ]);
      final w = _item(s, 'weight');
      expect((w.value, w.weightDay), (4.1, DateTime(2026, 11, 5)));
    });

    test('比べる記録がなければ範囲なし。記録がなければ値なし', () {
      final one = _item(
        _status([...usual, ..._records('weight', _yesterday, 1, kg: 4)]),
        'weight',
      );
      expect((one.value, one.hasRule, one.min), (4, false, null));
      final none = _item(_status(usual), 'weight');
      expect(none.value, isNull);
    });
  });

  test('UT-HS-07 きのうと今日の外れ値は、いつもとの差の通知（detectAnomalies）と一致する', () {
    final records = [
      ..._usual(_yesterday, 28),
      ..._records('food', _yesterday, 1),
      ..._records('urine', _yesterday, 1),
      ..._records('vomit', DateTime(2026, 11, 10), 2),
    ];
    final notified = detectAnomalies(
      cats: const [_cat],
      records: records,
      method: AnomalyMethod.statistical,
      now: _now,
    );
    Set<(String, AnomalyDirection)> shown(DateTime day) => {
      for (final i in _status(records, day: day).items)
        if (i.outlier case final d?) (i.kind, d),
    };
    Set<(String, AnomalyDirection)> sent(DateTime day) => {
      for (final a in notified)
        if (a.day == day) (a.kind, a.direction),
    };
    expect(shown(_yesterday), sent(_yesterday));
    expect(shown(DateTime(2026, 11, 10)), sent(DateTime(2026, 11, 10)));
    expect(shown(DateTime(2026, 11, 10)), isNotEmpty);
  });
}
