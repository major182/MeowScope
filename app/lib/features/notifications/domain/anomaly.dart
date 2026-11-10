import 'dart:convert';
import 'dart:math';

import '../../records/domain/record_kind.dart';
import '../data/notifier.dart';
import 'notification_settings.dart';
import 'reminder_plan.dart';

/// 回数で判定する記録の種類（BR-31。薬・ブラシ・独自の項目は判定しない）
const anomalyCountKinds = ['food', 'water', 'urine', 'stool', 'vomit'];

/// 体重の、ふだんとの差の既定（±5%。BR-20・31）
const defaultWeightPercent = 5;

/// 統計で判定するのに要る、記録のある日数（BR-31）
const minRecordDays = 7;

/// ふだんとして見る日数（直近28日。BR-31）
const usualDays = 28;

/// 判定に使う記録（記録の画面の RecordEntry から作る）
class AnomalyRecord {
  const AnomalyRecord({
    required this.catId,
    required this.kind,
    required this.recordedAt,
    this.valueNumber,
  });

  final String catId;

  /// 記録項目の種類（RecordKind の名前）
  final String kind;

  /// 端末の時刻
  final DateTime recordedAt;
  final double? valueNumber;
}

/// 判定の対象の猫（お別れの猫は渡さない）
class AnomalyCat {
  const AnomalyCat({required this.id, required this.name, this.thresholds});

  final String id;
  final String name;

  /// しきい値（S-47）。DB 設計書の形の JSON
  final String? thresholds;
}

/// 猫ごとのしきい値（S-47、BR-20）
class CatThresholds {
  const CatThresholds({this.counts = const {}, this.weightPercent});

  /// 種類ごとの1日の下限と上限。どちらも空なら判定しない
  final Map<String, ({int? min, int? max})> counts;

  /// 体重の、ふだんとの差の割合（%）。空なら既定（5%）
  final int? weightPercent;

  /// 保存した JSON から作る。壊れていたら空（判定しない）
  static CatThresholds parse(String? json) {
    if (json == null) {
      return const CatThresholds();
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CatThresholds(
        counts: {
          for (final kind in anomalyCountKinds)
            if (map[kind] case final Map<String, dynamic> rule)
              kind: (min: rule['min'] as int?, max: rule['max'] as int?),
        },
        weightPercent:
            (map['weight'] as Map<String, dynamic>?)?['percent'] as int?,
      );
    } on Object {
      return const CatThresholds();
    }
  }

  /// 保存と同期に使う JSON の形。何もなければ null
  String? toJson() {
    final map = <String, Object>{
      for (final MapEntry(key: kind, value: rule) in counts.entries)
        if (rule.min != null || rule.max != null)
          kind: {'min': ?rule.min, 'max': ?rule.max},
      if (weightPercent case final percent?) 'weight': {'percent': percent},
    };
    return map.isEmpty ? null : jsonEncode(map);
  }
}

enum AnomalyDirection { low, high }

/// 見つかった「いつもとの差」
class Anomaly {
  const Anomaly({
    required this.catId,
    required this.catName,
    required this.kind,
    required this.direction,
    required this.day,
    required this.observed,
    required this.usual,
  });

  final String catId;
  final String catName;

  /// 記録項目の種類（`weight` は体重）
  final String kind;
  final AnomalyDirection direction;

  /// 判定した日（回数は前日か今日、体重は最新の記録の日）
  final DateTime day;

  /// その日の回数、または体重の差の割合（%、絶対値）
  final num observed;

  /// ふだんの回数（平均や、しきい値の下限・上限）。体重は使わない
  final num usual;

  /// 同じ内容を1日1回にするための鍵（BR-12）
  String get key =>
      '$catId.$kind.${direction.name}.${day.year}-${day.month}-${day.day}';
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// いつもとの差を判定する（F-AN-01、BR-20・31）
///
/// [records] は直近29日と今日の記録。判定は、前日（記録が出そろった1日）の回数の少なすぎ・多すぎと、
/// 今日の回数の多すぎ、最新の体重（前日か今日の記録）の増減。前日に記録が1件もない猫は、前日の回数を判定しない
/// （家族が記録していないだけかもしれないため）
List<Anomaly> detectAnomalies({
  required List<AnomalyCat> cats,
  required List<AnomalyRecord> records,
  required AnomalyMethod method,
  required DateTime now,
}) {
  final today = _day(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final windowStart = yesterday.subtract(const Duration(days: usualDays));
  final result = <Anomaly>[];
  for (final cat in cats) {
    final mine = [
      for (final r in records)
        if (r.catId == cat.id) r,
    ];
    int countOn(DateTime day, String kind) =>
        mine.where((r) => r.kind == kind && _day(r.recordedAt) == day).length;
    final recordedYesterday = mine.any((r) => _day(r.recordedAt) == yesterday);
    // ふだん：前日より前の28日のうち、その猫の記録が1件でもある日
    final usualDaysSet = {
      for (final r in mine)
        if (!_day(r.recordedAt).isBefore(windowStart) &&
            _day(r.recordedAt).isBefore(yesterday))
          _day(r.recordedAt),
    };
    final thresholds = CatThresholds.parse(cat.thresholds);

    void add(
      String kind,
      AnomalyDirection d,
      DateTime day,
      num obs,
      num usual,
    ) => result.add(
      Anomaly(
        catId: cat.id,
        catName: cat.name,
        kind: kind,
        direction: d,
        day: day,
        observed: obs,
        usual: usual,
      ),
    );

    for (final kind in anomalyCountKinds) {
      final y = countOn(yesterday, kind);
      final t = countOn(today, kind);
      if (method == AnomalyMethod.statistical) {
        if (usualDaysSet.length < minRecordDays) {
          continue;
        }
        final counts = [for (final d in usualDaysSet) countOn(d, kind)];
        final mean = counts.reduce((a, b) => a + b) / counts.length;
        final sd = sqrt(
          counts.map((c) => pow(c - mean, 2)).reduce((a, b) => a + b) /
              counts.length,
        );
        final low = mean - 2 * sd;
        final high = mean + 2 * sd;
        // 1回以上の違いがあるときだけ（いつも同じ回数で標準偏差が 0 のとき、わずかな違いで出さないため）
        if (recordedYesterday && y < low && mean - y >= 1) {
          add(kind, AnomalyDirection.low, yesterday, y, mean);
        }
        if (recordedYesterday && y > high && y - mean >= 1) {
          add(kind, AnomalyDirection.high, yesterday, y, mean);
        }
        if (t > high && t - mean >= 1) {
          add(kind, AnomalyDirection.high, today, t, mean);
        }
      } else if (thresholds.counts[kind] case final rule?) {
        if (rule.min case final min? when recordedYesterday && y < min) {
          add(kind, AnomalyDirection.low, yesterday, y, min);
        }
        if (rule.max case final max?) {
          if (recordedYesterday && y > max) {
            add(kind, AnomalyDirection.high, yesterday, y, max);
          }
          if (t > max) {
            add(kind, AnomalyDirection.high, today, t, max);
          }
        }
      }
    }

    // 体重：最新の記録（前日か今日）を、それより前の28日の平均と比べる
    final weights = [
      for (final r in mine)
        if (r.kind == 'weight' && r.valueNumber != null) r,
    ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (weights.isEmpty ||
        _day(weights.last.recordedAt).isBefore(yesterday) ||
        (method == AnomalyMethod.statistical &&
            usualDaysSet.length < minRecordDays)) {
      continue;
    }
    final latest = weights.last;
    final from = _day(latest.recordedAt)
        .subtract(const Duration(days: usualDays));
    final before = [
      for (final w in weights)
        if (_day(w.recordedAt).isBefore(_day(latest.recordedAt)) &&
            !_day(w.recordedAt).isBefore(from))
          w.valueNumber!,
    ];
    if (before.isEmpty) {
      continue;
    }
    final mean = before.reduce((a, b) => a + b) / before.length;
    // 小数の誤差（4.2kg と 4.0kg で 5.000…01% になるなど）で境界を越えないよう、小数1桁に丸めてから比べる
    final percent = ((latest.valueNumber! - mean) / mean * 1000).round() / 10;
    final limit = method == AnomalyMethod.threshold
        ? thresholds.weightPercent ?? defaultWeightPercent
        : defaultWeightPercent;
    if (percent.abs() > limit) {
      add(
        'weight',
        percent > 0 ? AnomalyDirection.high : AnomalyDirection.low,
        _day(latest.recordedAt),
        percent.abs().round(),
        limit,
      );
    }
  }
  return result;
}

/// いつもとの差の通知を押したときに開く場所：その猫と項目の統計（体重は体重のグラフ）
String anomalyPayload(Anomaly a) => Uri(
  path: '/stats',
  queryParameters: {'cat': a.catId, 'kind': a.kind},
).toString();

/// いつもとの差の通知の文（画面設計書 4章、F-NT-02）
///
/// 回数は「ミケのご飯がいつもより少なめです」と、2行目に「きのう 1回（ふだん 3回くらい）」。
/// しきい値で判定したときは、2行目のかっこを「下限 1回」「上限 5回」にする。
/// 体重は「ミケの体重がいつもより 6% 増えています」（2行目なし）
AppNotification anomalyNotification(
  Anomaly a, {
  required AnomalyMethod method,
  required DateTime now,
}) {
  final id = notificationId('anomaly', a.key);
  final low = a.direction == AnomalyDirection.low;
  if (a.kind == 'weight') {
    return AppNotification(
      id: id,
      title: '${a.catName}の体重がいつもより ${a.observed}% ${low ? '減って' : '増えて'}います',
      payload: anomalyPayload(a),
    );
  }
  final label = RecordKind.values.byName(a.kind).label;
  final day = _day(a.day) == _day(now) ? 'きょう' : 'きのう';
  final usual = method == AnomalyMethod.threshold
      ? '${low ? '下限' : '上限'} ${a.usual}回'
      : 'ふだん ${a.usual.round()}回くらい';
  return AppNotification(
    id: id,
    title: '${a.catName}の$labelがいつもより${low ? '少なめ' : '多め'}です',
    body: '$day ${a.observed}回（$usual）',
    payload: anomalyPayload(a),
  );
}
