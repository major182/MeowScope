import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/presentation/calendar_providers.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/record_kind.dart';
import '../../records/presentation/record_providers.dart';
import '../domain/stats.dart';

/// 統計（S-30）。1匹を選び、体重の推移と項目ごとの回数を週と月で出す
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, this.today, this.catId, this.kind});

  /// 今日の日付。テストで差し替える
  final DateTime? today;

  /// 初めに選んでおく猫と、記録項目の種類（いつもとの差の通知から開くとき。体重は `weight`）
  final String? catId;
  final String? kind;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late String? _catId = widget.catId;
  String? _typeId;
  var _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(filterCatsProvider).value ?? const [];
    final types = ref.watch(recordTypesProvider).value ?? const [];
    // 選んでいなければ（または選んだものが消えたら）先頭にする
    final catId = cats.any((c) => c.id == _catId)
        ? _catId
        : cats.firstOrNull?.id;
    final countTypes = [
      for (final t in types)
        if (t.kind != RecordKind.weight.name) t,
    ];
    // 通知から開いたときは、その種類の項目を選んでおく
    _typeId ??= countTypes.where((t) => t.kind == widget.kind).firstOrNull?.id;
    final typeId = countTypes.any((t) => t.id == _typeId)
        ? _typeId
        : countTypes.firstOrNull?.id;
    final days = periodDays(widget.today ?? DateTime.now(), _period);
    final entries = catId == null
        ? const <RecordEntry>[]
        : ref
                  .watch(
                    rangeRecordsProvider((
                      from: days.first,
                      to: DateTime(
                        days.last.year,
                        days.last.month,
                        days.last.day + 1,
                      ),
                      catId: catId,
                    )),
                  )
                  .value ??
              const [];
    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: catId == null
          ? const Center(child: Text('猫が登録されていません'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CatFilter(
                      selected: catId,
                      allowAll: false,
                      onChanged: (id) => setState(() => _catId = id),
                    ),
                    const Spacer(),
                    SegmentedButton<StatsPeriod>(
                      segments: [
                        for (final p in StatsPeriod.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) =>
                          setState(() => _period = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('体重 (kg)', style: Theme.of(context).textTheme.titleMedium),
                WeightChart(days: days, points: weightSeries(entries)),
                const Divider(height: 32),
                Row(
                  children: [
                    Text(
                      '回数の推移',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (typeId != null)
                      DropdownButton<String>(
                        value: typeId,
                        onChanged: (id) => setState(() => _typeId = id),
                        items: [
                          for (final t in countTypes)
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                        ],
                      ),
                  ],
                ),
                if (typeId != null)
                  CountChart(
                    days: days,
                    counts: dailyCounts(entries, days, typeId),
                  ),
              ],
            ),
    );
  }
}

/// 日付の目盛りを出す日か（週は毎日、月は最後の日から5日おき）。折れ線グラフの縦の線もこの日に引く
bool isLabelDay(List<DateTime> days, double value) {
  final i = value.round();
  if (i < 0 || i >= days.length || value != i) {
    return false;
  }
  final step = days.length > 7 ? 5 : 1;
  return (days.length - 1 - i) % step == 0;
}

/// 日付の目盛り
Widget _dayLabel(List<DateTime> days, double value) {
  if (!isLabelDay(days, value)) {
    return const SizedBox.shrink();
  }
  final d = days[value.round()];
  return Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 10));
}

FlTitlesData _titles(List<DateTime> days, {required double leftInterval}) =>
    FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval: leftInterval,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) => _dayLabel(days, value),
        ),
      ),
    );

/// 体重の折れ線グラフ。横軸は期間の最初の日からの日数
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.days, required this.points});

  final List<DateTime> days;
  final List<WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('この期間の体重の記録はありません')),
      );
    }
    final start = days.first;
    final spots = [
      for (final p in points)
        FlSpot(p.at.difference(start).inMinutes / Duration.minutesPerDay, p.kg),
    ];
    final kgs = points.map((p) => p.kg);
    // 上下に少し余白を取る
    final minY = (kgs.reduce(math.min) - 0.5).floorToDouble().clamp(0, 30);
    final maxY = (kgs.reduce(math.max) + 0.5).ceilToDouble();
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: days.length.toDouble(),
          minY: minY.toDouble(),
          maxY: maxY,
          titlesData: _titles(days, leftInterval: 0.5),
          // 縦の線は日付の目盛りと同じ日にだけ引く（自動の間隔だと目盛りとずれる）
          gridData: FlGridData(
            verticalInterval: 1,
            checkToShowVerticalLine: (value) => isLabelDay(days, value),
          ),
          lineBarsData: [LineChartBarData(spots: spots, barWidth: 2)],
        ),
      ),
    );
  }
}

/// 日ごとの回数の棒グラフ
class CountChart extends StatelessWidget {
  const CountChart({super.key, required this.days, required this.counts});

  final List<DateTime> days;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold(0, math.max);
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: 0,
          // 回数が0でも目盛りが出るよう、最低1にする
          maxY: math.max(maxCount, 1).toDouble(),
          titlesData: _titles(days, leftInterval: 1),
          // 棒そのものが日付の位置を示すので、縦の線は引かない（棒の位置とずれて見えるため）
          gridData: const FlGridData(drawVerticalLine: false),
          barGroups: [
            for (var i = 0; i < counts.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(toY: counts[i].toDouble())],
              ),
          ],
        ),
      ),
    );
  }
}
