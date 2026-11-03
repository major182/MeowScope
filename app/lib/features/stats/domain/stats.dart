import '../../calendar/domain/calendar_month.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/record_kind.dart';

/// 統計の期間（F-ST-01）。今日までの日数を日ごとに集計する
enum StatsPeriod {
  week('週', 7),
  month('月', 30);

  const StatsPeriod(this.label, this.days);

  final String label;
  final int days;
}

/// 期間の日付（古い順、最後が今日）
List<DateTime> periodDays(DateTime today, StatsPeriod period) {
  final end = dateOnly(today);
  return [
    for (var i = period.days - 1; i >= 0; i--)
      DateTime(end.year, end.month, end.day - i),
  ];
}

/// 日ごとの回数（days と同じ順）。recordTypeId の記録だけを数える
List<int> dailyCounts(
  List<RecordEntry> entries,
  List<DateTime> days,
  String recordTypeId,
) {
  final counts = {for (final d in days) d: 0};
  for (final e in entries) {
    final day = dateOnly(e.recordedAt);
    if (e.recordTypeId == recordTypeId && counts.containsKey(day)) {
      counts[day] = counts[day]! + 1;
    }
  }
  return [for (final d in days) counts[d]!];
}

/// 体重の1点
typedef WeightPoint = ({DateTime at, double kg});

/// 体重の記録のうち、数値があるものを古い順に返す
List<WeightPoint> weightSeries(List<RecordEntry> entries) {
  final points = [
    for (final e in entries)
      if (e.kind == RecordKind.weight.name && e.valueNumber != null)
        (at: e.recordedAt, kg: e.valueNumber!),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return points;
}
