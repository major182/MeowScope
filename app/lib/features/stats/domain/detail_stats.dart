/// Windows のくわしい統計（S-31。F-ST-04〜08、BR-42、Q-29）の計算
///
/// 画面から切り離して、単体テストで確かめる
library;

import '../../calendar/domain/calendar_month.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/record_kind.dart';

/// 期間の選び方（F-ST-04）。指定は開始日〜終了日（両端の日を含む）
enum DetailPeriod {
  week('週', 7),
  month('月', 30),
  year('年', 365),
  custom('指定', null);

  const DetailPeriod(this.label, this.days);

  final String label;

  /// 今日までの日数。指定のときは null
  final int? days;
}

/// 期間の日付（古い順）。週・月・年は今日まで、指定は [from]〜[to]。
/// 指定で両端がそろっていなければ空
List<DateTime> detailDays(
  DetailPeriod period,
  DateTime today, {
  DateTime? from,
  DateTime? to,
}) {
  if (period.days case final n?) {
    final end = dateOnly(today);
    return [
      for (var i = n - 1; i >= 0; i--)
        DateTime(end.year, end.month, end.day - i),
    ];
  }
  if (from == null || to == null || to.isBefore(from)) {
    return const [];
  }
  final start = dateOnly(from);
  final end = dateOnly(to);
  return [
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// グラフの1本の線：どの猫の、どの項目か
typedef SeriesKey = ({String catId, String typeId});

/// 線の1点。体重のない日・記録のない日（体重）は点を打たない
typedef SeriesPoint = ({int dayIndex, double value});

/// 1本の線。[weight] なら値は kg（右の目盛り）、そうでなければ回数（左の目盛り）
typedef Series = ({SeriesKey key, bool weight, List<SeriesPoint> points});

/// 選んだ猫と項目の組ごとに線を作る（F-ST-05・06）
///
/// 回数の項目は日ごとの回数（記録のない日は 0）。体重は、その日の最後の記録の値（記録のない日は点なし）。
/// [weightTypeIds] は体重の項目の ID
List<Series> buildSeries({
  required List<RecordEntry> entries,
  required List<DateTime> days,
  required List<String> catIds,
  required List<String> typeIds,
  required Set<String> weightTypeIds,
}) {
  final index = {for (final (i, d) in days.indexed) d: i};
  return [
    for (final catId in catIds)
      for (final typeId in typeIds)
        _series(entries, index, days.length, (
          catId: catId,
          typeId: typeId,
        ), weightTypeIds.contains(typeId)),
  ];
}

Series _series(
  List<RecordEntry> entries,
  Map<DateTime, int> index,
  int length,
  SeriesKey key,
  bool weight,
) {
  final mine = [
    for (final e in entries)
      if (e.catId == key.catId && e.recordTypeId == key.typeId) e,
  ];
  if (!weight) {
    final counts = List.filled(length, 0);
    for (final e in mine) {
      if (index[dateOnly(e.recordedAt)] case final i?) {
        counts[i]++;
      }
    }
    return (
      key: key,
      weight: false,
      points: [
        for (var i = 0; i < length; i++)
          (dayIndex: i, value: counts[i].toDouble()),
      ],
    );
  }
  // その日の最後の記録の値（同じ日に何度か量ったときは、最後のものを使う）
  final last = <int, RecordEntry>{};
  for (final e in mine) {
    final i = index[dateOnly(e.recordedAt)];
    if (i == null || e.valueNumber == null) {
      continue;
    }
    if (last[i] == null || e.recordedAt.isAfter(last[i]!.recordedAt)) {
      last[i] = e;
    }
  }
  return (
    key: key,
    weight: true,
    points: [
      for (final i in last.keys.toList()..sort())
        (dayIndex: i, value: last[i]!.valueNumber!),
    ],
  );
}

/// 体重の項目か
bool isWeightKind(String kind) => kind == RecordKind.weight.name;

/// 右の目盛り（体重）を左の目盛り（回数）に重ねるための換算（F-ST-06）
///
/// 体重の範囲（[min]〜[max] kg）を、回数の目盛りの 0〜[countMax] に引き伸ばす。
/// 体重の値が1つしかないときも線が見えるよう、上下に 0.5kg の幅を取る
class WeightScale {
  WeightScale({
    required double min,
    required double max,
    required this.countMax,
  }) : min = min == max ? min - 0.5 : min,
       max = min == max ? max + 0.5 : max;

  final double min;
  final double max;
  final double countMax;

  /// kg を左の目盛りの位置にする
  double toLeft(double kg) => (kg - min) / (max - min) * countMax;

  /// 左の目盛りの位置を kg にする（右の目盛りの文字に使う）
  double toKg(double left) => min + left / countMax * (max - min);
}
