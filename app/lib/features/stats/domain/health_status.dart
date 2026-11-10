import '../../notifications/domain/anomaly.dart';
import '../../notifications/domain/notification_settings.dart';

/// 体調のようすの1項目（F-ST-02）
class HealthItem {
  const HealthItem({
    required this.kind,
    this.value,
    this.weightDay,
    this.min,
    this.max,
    this.outlier,
    this.hasRule = true,
  });

  /// 記録項目の種類（`weight` は体重）
  final String kind;

  /// その日の回数、または体重（kg）。体重の記録がなければ null
  final num? value;

  /// 体重の記録の日（選んだ日より前の記録を出すとき）
  final DateTime? weightDay;

  /// 範囲内とする下限・上限（回数は回、体重は kg）。null の側は判定しない
  final num? min;
  final num? max;

  /// 外れ値なら、その向き
  final AnomalyDirection? outlier;

  /// しきい値の方式で、しきい値を決めていなければ false
  final bool hasRule;
}

/// 選んだ猫・日の体調のようす
class HealthStatus {
  const HealthStatus({
    this.items = const [],
    this.daysLeft = 0,
    this.recorded = true,
  });

  /// 記録項目の並び順。外れ値と範囲内に分けるのは画面で行う
  final List<HealthItem> items;

  /// 統計で判定するのに足りない、記録のある日数（0 なら判定できる）
  final int daysLeft;

  /// その日に記録が1件でもあるか。ない日は「少なすぎ」を判定しない
  final bool recorded;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 選んだ日の体調のようすを作る（F-ST-02。範囲の計算はいつもとの差の通知と同じ：BR-20・31）
///
/// [records] はその猫の、選んだ日までの記録（ふだんの28日と、体重の比べる分を含む）。
/// 今日は1日の途中なので、少なすぎは判定しない。今日のふだんは、通知と同じく前日より前の28日で見る
HealthStatus healthStatus({
  required AnomalyCat cat,
  required List<AnomalyRecord> records,
  required AnomalyMethod method,
  required DateTime day,
  required DateTime now,
}) {
  final target = _day(day);
  final today = _day(now);
  final isToday = target == today;
  final base = isToday ? today.subtract(const Duration(days: 1)) : target;
  final windowStart = base.subtract(const Duration(days: usualDays));
  final mine = [
    for (final r in records)
      if (r.catId == cat.id) r,
  ];
  int countOn(DateTime d, String kind) =>
      mine.where((r) => r.kind == kind && _day(r.recordedAt) == d).length;
  final recorded = mine.any((r) => _day(r.recordedAt) == target);
  final judgeLow = recorded && !isToday;
  final usualDaysSet = {
    for (final r in mine)
      if (!_day(r.recordedAt).isBefore(windowStart) &&
          _day(r.recordedAt).isBefore(base))
        _day(r.recordedAt),
  };
  if (method == AnomalyMethod.statistical &&
      usualDaysSet.length < minRecordDays) {
    return HealthStatus(
      daysLeft: minRecordDays - usualDaysSet.length,
      recorded: recorded,
    );
  }
  final thresholds = CatThresholds.parse(cat.thresholds);

  AnomalyDirection? judge(num value, num? min, num? max) => switch (value) {
    _ when min != null && value < min => AnomalyDirection.low,
    _ when max != null && value > max => AnomalyDirection.high,
    _ => null,
  };

  final items = <HealthItem>[];
  for (final kind in anomalyCountKinds) {
    final value = countOn(target, kind);
    final CountRange? range = method == AnomalyMethod.statistical
        ? usualCountRange([for (final d in usualDaysSet) countOn(d, kind)])
        : thresholds.counts[kind];
    if (range == null) {
      items.add(HealthItem(kind: kind, value: value, hasRule: false));
      continue;
    }
    final min = judgeLow ? range.min : null;
    items.add(
      HealthItem(
        kind: kind,
        value: value,
        min: min,
        max: range.max,
        outlier: judge(value, min, range.max),
      ),
    );
  }

  // 体重：選んだ日かそれより前の最新の記録を、それより前の28日の平均と比べる
  final weights = [
    for (final r in mine)
      if (r.kind == 'weight' &&
          r.valueNumber != null &&
          !_day(r.recordedAt).isAfter(target))
        (at: r.recordedAt, kg: r.valueNumber!),
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (weights.isEmpty) {
    items.add(const HealthItem(kind: 'weight'));
  } else {
    final latest = weights.last;
    final change = weightChange(latest, weights);
    final percent = method == AnomalyMethod.threshold
        ? thresholds.weightPercent ?? defaultWeightPercent
        : defaultWeightPercent;
    final weightDay = _day(latest.at) == target ? null : _day(latest.at);
    if (change == null) {
      items.add(
        HealthItem(
          kind: 'weight',
          value: latest.kg,
          weightDay: weightDay,
          hasRule: false,
        ),
      );
    } else {
      items.add(
        HealthItem(
          kind: 'weight',
          value: latest.kg,
          weightDay: weightDay,
          min: change.mean * (100 - percent) / 100,
          max: change.mean * (100 + percent) / 100,
          outlier: change.percent.abs() > percent
              ? (change.percent > 0
                    ? AnomalyDirection.high
                    : AnomalyDirection.low)
              : null,
        ),
      );
    }
  }
  return HealthStatus(items: items, recorded: recorded);
}
