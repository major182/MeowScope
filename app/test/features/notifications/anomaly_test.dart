import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/notifications/domain/anomaly.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';

void main() {
  final now = DateTime(2026, 11, 20, 12);
  final today = DateTime(2026, 11, 20);
  final yesterday = DateTime(2026, 11, 19);
  const mike = AnomalyCat(id: 'c1', name: 'ミケ');

  /// [day] に [kind] を [count] 回記録した
  List<AnomalyRecord> times(DateTime day, int count, {String kind = 'food'}) =>
      [
        for (var i = 0; i < count; i++)
          AnomalyRecord(
            catId: 'c1',
            kind: kind,
            recordedAt: day.add(Duration(hours: 8 + i)),
          ),
      ];

  /// 前日より前の [days] 日、毎日 [perDay] 回（[perDayOf] があれば日ごとに変える）
  List<AnomalyRecord> usual(
    int days, {
    int perDay = 3,
    int Function(int)? perDayOf,
  }) => [
    for (var i = 1; i <= days; i++)
      ...times(
        yesterday.subtract(Duration(days: i)),
        perDayOf?.call(i) ?? perDay,
      ),
  ];

  List<Anomaly> detect(
    List<AnomalyRecord> records, {
    AnomalyMethod method = AnomalyMethod.statistical,
    AnomalyCat cat = mike,
  }) =>
      detectAnomalies(cats: [cat], records: records, method: method, now: now);

  group('UT-AN-01 統計：回数（BR-31）', () {
    test('いつも3回の猫が前日1回なら「少なめ」。前日も3回なら何もない', () {
      final low = detect([...usual(10), ...times(yesterday, 1)]);
      expect(low.single.direction, AnomalyDirection.low);
      expect(low.single.day, yesterday);
      expect(low.single.observed, 1);
      expect(low.single.usual, 3);
      expect(detect([...usual(10), ...times(yesterday, 3)]), isEmpty);
    });

    test('今日の回数が多すぎれば、今日の分として「多め」', () {
      final high = detect([
        ...usual(10),
        ...times(yesterday, 3),
        ...times(today, 6),
      ]);
      expect(high.single.direction, AnomalyDirection.high);
      expect(high.single.day, today);
    });

    test('前日に記録が1件もない猫は、前日の少なすぎを判定しない（記録していないだけかもしれないため）', () {
      expect(detect(usual(10)), isEmpty);
    });

    test('境界値：記録のある日が6日なら判定せず、7日なら判定する', () {
      expect(detect([...usual(6), ...times(yesterday, 1)]), isEmpty);
      expect(detect([...usual(7), ...times(yesterday, 1)]), hasLength(1));
    });

    test('境界値：平均±2標準偏差ちょうどは外れ値にしない（2回と4回を交互＝平均3・標準偏差1。下限1）', () {
      final alternating = usual(10, perDayOf: (i) => i.isEven ? 2 : 4);
      expect(detect([...alternating, ...times(yesterday, 1)]), isEmpty);
      expect(
        detect([...alternating, ...times(yesterday, 1, kind: 'water')]),
        isNotEmpty,
      );
    });
  });

  group('UT-AN-02 しきい値（S-47、BR-20）', () {
    const rule = AnomalyCat(
      id: 'c1',
      name: 'ミケ',
      thresholds: '{"food":{"min":2,"max":4}}',
    );

    test('前日が下限より少なければ「少なめ」、上限より多ければ「多め」。今日も上限で判定する。記録が7日分なくても判定する', () {
      final low = detect(
        times(yesterday, 1),
        method: AnomalyMethod.threshold,
        cat: rule,
      );
      expect(low.single.direction, AnomalyDirection.low);
      expect(low.single.usual, 2);
      final high = detect(
        [...times(yesterday, 5), ...times(today, 5)],
        method: AnomalyMethod.threshold,
        cat: rule,
      );
      expect(high.map((a) => a.day), [yesterday, today]);
    });

    test('境界値：下限ちょうど・上限ちょうどは何もない。しきい値のない種類（水）は判定しない', () {
      expect(
        detect(
          [...times(yesterday, 2), ...times(today, 4)],
          method: AnomalyMethod.threshold,
          cat: rule,
        ),
        isEmpty,
      );
      // 前日に水を9回記録してもしきい値がないので判定しない。ご飯は前日0回なので「少なめ」になる
      final water = detect(
        times(yesterday, 9, kind: 'water'),
        method: AnomalyMethod.threshold,
        cat: rule,
      );
      expect(water.map((a) => (a.kind, a.direction)), [
        ('food', AnomalyDirection.low),
      ]);
    });
  });

  group('UT-AN-03 体重', () {
    List<AnomalyRecord> weights(double latest, {DateTime? on}) => [
      for (var i = 2; i <= 5; i++)
        AnomalyRecord(
          catId: 'c1',
          kind: 'weight',
          recordedAt: yesterday.subtract(Duration(days: i)),
          valueNumber: 4.0,
        ),
      AnomalyRecord(
        catId: 'c1',
        kind: 'weight',
        recordedAt: on ?? today,
        valueNumber: latest,
      ),
    ];

    test('直近の平均（4.0kg）から5%を超えて増えれば「増えた」。差の割合を整数に四捨五入して持つ', () {
      final a = detect([...usual(10), ...weights(4.4)]);
      expect(a.single.kind, 'weight');
      expect(a.single.direction, AnomalyDirection.high);
      expect(a.single.observed, 10);
      expect(
        detect([...usual(10), ...weights(3.7)]).single.direction,
        AnomalyDirection.low,
      );
    });

    test('境界値：ちょうど5%は何もない。最新の記録が前日より前なら判定しない', () {
      expect(detect([...usual(10), ...weights(4.2)]), isEmpty);
      expect(
        detect([
          ...usual(10),
          ...weights(4.5, on: yesterday.subtract(const Duration(days: 1))),
        ]),
        isEmpty,
      );
    });

    test('しきい値の方式では、猫ごとの割合（10%）を使う', () {
      const rule = AnomalyCat(
        id: 'c1',
        name: 'ミケ',
        thresholds: '{"weight":{"percent":10}}',
      );
      expect(
        detect(weights(4.3), method: AnomalyMethod.threshold, cat: rule),
        isEmpty,
      );
      expect(
        detect(weights(4.5), method: AnomalyMethod.threshold, cat: rule),
        hasLength(1),
      );
    });
  });

  test('UT-AN-04 しきい値の保存の形：読み書きで同じになり、空なら null。壊れた値は空として読む', () {
    const t = CatThresholds(
      counts: {'food': (min: 1, max: null), 'vomit': (min: null, max: 2)},
      weightPercent: 8,
    );
    final json = t.toJson()!;
    final back = CatThresholds.parse(json);
    expect(back.counts['food'], (min: 1, max: null));
    expect(back.counts['vomit'], (min: null, max: 2));
    expect(back.weightPercent, 8);
    expect(const CatThresholds().toJson(), isNull);
    expect(CatThresholds.parse('壊れた').counts, isEmpty);
  });

  test('UT-AN-05 同じ内容を1日1回にする鍵は、猫・種類・向き・日で決まる（BR-12）', () {
    final a = detect([...usual(10), ...times(yesterday, 1)]).single;
    expect(a.key, 'c1.food.low.2026-11-19');
  });
}
