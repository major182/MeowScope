import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/today.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../calendar/domain/calendar_month.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../records/data/record_repository.dart';
import '../../records/presentation/record_providers.dart';
import '../domain/detail_stats.dart';

/// 1つのグラフに重ねる線の数の上限。多すぎると見分けられないため
const maxSeries = 8;

/// 線の色。隣り合っても見分けやすい色を順に使う（色だけに頼らないよう、凡例に名前も出す）
const seriesColors = [
  Color(0xFFC2662D), // アプリの色（茶）
  Color(0xFF2B6CB0), // 青
  Color(0xFF2F855A), // 緑
  Color(0xFF9B2C2C), // 赤
  Color(0xFF6B46C1), // 紫
  Color(0xFFB7791F), // 黄土
  Color(0xFF2C7A7B), // 青緑
  Color(0xFF4A5568), // 灰
];

/// くわしい統計（S-31。F-ST-04〜06、BR-42）。Windows だけで、S-30 の「くわしく見る」から開く
///
/// 期間を自由に選び、2匹以上の猫と2つ以上の項目を同じグラフに重ねる。
/// 回数は左の目盛り、体重は右の目盛り（kg）で読む
class DetailStatsScreen extends ConsumerStatefulWidget {
  const DetailStatsScreen({super.key});

  @override
  ConsumerState<DetailStatsScreen> createState() => _DetailStatsScreenState();
}

class _DetailStatsScreenState extends ConsumerState<DetailStatsScreen> {
  var _period = DetailPeriod.month;
  DateTime? _from;
  DateTime? _to;

  /// 選んだ猫と項目（選んだ順）。null は「まだ選んでいない」（最初の猫・最初の項目にする）
  List<String>? _cats;
  List<String>? _types;

  Future<void> _pickDate({required bool start}) async {
    final today = dateOnly(ref.read(nowProvider)());
    final picked = await showAppDatePicker(
      context: context,
      weekStart: ref.read(weekStartProvider).value ?? WeekStart.sunday,
      initialDate: (start ? _from : _to) ?? (start ? (_to ?? today) : today),
      firstDate: start ? DateTime(2000) : (_from ?? DateTime(2000)),
      lastDate: start ? (_to ?? today) : today,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => start ? _from = picked : _to = picked);
  }

  /// 選ぶ・外す。最後の1つは外せない（何もないグラフにしないため）
  static List<String> _toggle(List<String> current, String id) {
    if (current.contains(id)) {
      if (current.length == 1) {
        return current;
      }
      // 「..」は式の中でいちばん後に効くので、三項の式とは分けて書く（最後の1つまで消してしまわないため）
      return [...current]..remove(id);
    }
    return [...current, id];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(weekStartProvider);
    final cats = ref.watch(filterCatsProvider).value ?? const [];
    final types = ref.watch(recordTypesProvider).value ?? const [];
    final today = ref.watch(nowProvider)();
    // 消えた猫・項目は外す。まだ選んでいなければ先頭にする
    final catIds = [
      for (final id in _cats ?? [?cats.firstOrNull?.id])
        if (cats.any((c) => c.id == id)) id,
    ];
    final typeIds = [
      for (final id in _types ?? [?types.firstOrNull?.id])
        if (types.any((t) => t.id == id)) id,
    ];
    final days = detailDays(_period, today, from: _from, to: _to);
    final entries = days.isEmpty
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
                      catId: null,
                    )),
                  )
                  .value ??
              const [];
    final series = buildSeries(
      entries: entries,
      days: days,
      catIds: catIds,
      typeIds: typeIds,
      weightTypeIds: {
        for (final t in types)
          if (isWeightKind(t.kind)) t.id,
      },
    );
    final catName = {for (final c in cats) c.id: c.name};
    final typeName = {for (final t in types) t.id: t.name};
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('くわしい統計')),
      body: cats.isEmpty
          ? const Center(child: Text('猫が登録されていません'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('期間', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<DetailPeriod>(
                      segments: [
                        for (final p in DetailPeriod.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) =>
                          setState(() => _period = s.single),
                    ),
                    if (_period == DetailPeriod.custom) ...[
                      OutlinedButton(
                        onPressed: () => _pickDate(start: true),
                        child: Text(_from == null ? '開始日' : _label(_from!)),
                      ),
                      const Text('〜'),
                      OutlinedButton(
                        onPressed: () => _pickDate(start: false),
                        child: Text(_to == null ? '終了日' : _label(_to!)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text('猫（重ねて比べる）', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in cats)
                      FilterChip(
                        label: Text(c.name),
                        selected: catIds.contains(c.id),
                        onSelected: (_) =>
                            setState(() => _cats = _toggle(catIds, c.id)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('項目（重ねて見る）', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in types)
                      FilterChip(
                        label: Text(t.name),
                        selected: typeIds.contains(t.id),
                        onSelected: (_) =>
                            setState(() => _types = _toggle(typeIds, t.id)),
                      ),
                  ],
                ),
                const Divider(height: 32),
                if (days.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('開始日と終了日を選んでください')),
                  )
                else ...[
                  if (series.length > maxSeries)
                    Text(
                      '線が多いため、はじめの$maxSeries本だけを出しています。猫か項目を減らしてください',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  // どの線にも点がなければ、空のグラフの代わりに案内を出す
                  if (series.every((s) => s.records == 0))
                    const SizedBox(
                      height: 120,
                      child: Center(child: Text('この期間の記録はありません')),
                    )
                  else
                    OverlayChart(
                      days: days,
                      series: series.take(maxSeries).toList(),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      for (final (i, s) in series.take(maxSeries).indexed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              color: seriesColors[i % seriesColors.length],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${catName[s.key.catId]}・${typeName[s.key.typeId]}'
                              '${s.weight ? '（kg・右）' : '（回・左）'}',
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text('時間帯の傾向', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '選んだ猫の記録を合わせて、項目ごとにどの時間帯に多いかを出します',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  HourTable(
                    names: [for (final id in typeIds) typeName[id] ?? ''],
                    counts: hourCounts(
                      entries: entries,
                      days: days,
                      catIds: catIds,
                      typeIds: typeIds,
                    ),
                  ),
                  const Divider(height: 32),
                  Text('日ごとの表', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DailyTable(
                    headers: [
                      for (final s in series)
                        '${catName[s.key.catId]}・${typeName[s.key.typeId]}'
                            '${s.weight ? '（kg）' : '（回）'}',
                    ],
                    rows: dailyTable(days, series),
                  ),
                ],
              ],
            ),
    );
  }

  static String _label(DateTime d) => '${d.year}/${d.month}/${d.day}';
}

/// 重ねた折れ線グラフ（F-ST-05・06）。回数は左の目盛り、体重は右の目盛り（kg）
class OverlayChart extends StatelessWidget {
  const OverlayChart({super.key, required this.days, required this.series});

  final List<DateTime> days;
  final List<Series> series;

  @override
  Widget build(BuildContext context) {
    final counts = [
      for (final s in series)
        if (!s.weight) ...s.points.map((p) => p.value),
    ];
    final kgs = [
      for (final s in series)
        if (s.weight) ...s.points.map((p) => p.value),
    ];
    // 回数の目盛りの上端。回数がなくても体重を描けるよう、最低 4 にする
    final countMax = math
        .max(4, counts.fold<double>(0, math.max).ceil())
        .toDouble();
    final scale = kgs.isEmpty
        ? null
        : WeightScale(
            min: kgs.reduce(math.min),
            max: kgs.reduce(math.max),
            countMax: countMax,
          );
    final step = math.max(1, (days.length / 8).ceil());
    return SizedBox(
      height: 320,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, days.length - 1).toDouble(),
          minY: 0,
          maxY: countMax,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              axisNameWidget: counts.isEmpty ? null : const Text('回'),
              sideTitles: SideTitles(
                showTitles: counts.isNotEmpty,
                reservedSize: 36,
                interval: math.max(1, (countMax / 4).ceil()).toDouble(),
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: scale == null ? null : const Text('kg'),
              sideTitles: SideTitles(
                showTitles: scale != null,
                reservedSize: 44,
                interval: countMax / 4,
                getTitlesWidget: (value, meta) => Text(
                  scale!.toKg(value).toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  // 最後の日から step 日おきに日付を出す
                  if (value != i ||
                      i < 0 ||
                      i >= days.length ||
                      (days.length - 1 - i) % step != 0) {
                    return const SizedBox.shrink();
                  }
                  final d = days[i];
                  return Text(
                    '${d.month}/${d.day}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            for (final (i, s) in series.indexed)
              LineChartBarData(
                spots: [
                  for (final p in s.points)
                    FlSpot(
                      p.dayIndex.toDouble(),
                      s.weight ? scale!.toLeft(p.value) : p.value,
                    ),
                ],
                color: seriesColors[i % seriesColors.length],
                barWidth: 2,
                // 体重は点だけでも読めるよう点を出し、回数は日が多いと込み合うので出さない
                dotData: FlDotData(show: s.weight || days.length <= 31),
                // 体重は破線にして、回数の線と形でも見分けられるようにする
                dashArray: s.weight ? [6, 3] : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// 時間帯の傾向（F-ST-07）。行が項目、列が時間帯で、記録が多いほど濃い色にする（数も出す）
class HourTable extends StatelessWidget {
  const HourTable({super.key, required this.names, required this.counts});

  final List<String> names;
  final List<List<int>> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final most = counts.expand((c) => c).fold(0, math.max);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(64),
        columnWidths: const {0: FixedColumnWidth(96)},
        border: TableBorder.all(color: scheme.outlineVariant),
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (var b = 0; b < hourBlocks; b++)
                _cell(
                  Text(hourBlockLabel(b), style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          for (final (i, name) in names.indexed)
            TableRow(
              children: [
                _cell(Text(name)),
                for (final n in counts[i])
                  Container(
                    // 一番多いところを一番濃くする。0 は色を付けない
                    color: n == 0 || most == 0
                        ? null
                        : scheme.primary.withValues(
                            alpha: 0.15 + 0.6 * n / most,
                          ),
                    child: _cell(Text('$n')),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.all(6),
    child: Center(child: child),
  );
}

/// 日ごとの表（F-ST-08）。行が日（新しい順）、列が猫と項目の組
class DailyTable extends StatelessWidget {
  const DailyTable({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<TableRowData> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 32,
        columns: [
          const DataColumn(label: Text('日付')),
          for (final h in headers) DataColumn(label: Text(h), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(
                  Text('${r.day.month}/${r.day.day}（${_weekday(r.day)}）'),
                ),
                for (final c in r.cells) DataCell(Text(c)),
              ],
            ),
        ],
      ),
    );
  }

  static String _weekday(DateTime d) => '月火水木金土日'[d.weekday - 1];
}
