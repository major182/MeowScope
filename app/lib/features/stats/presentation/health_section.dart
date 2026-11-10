import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../notifications/domain/anomaly.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../records/domain/record_kind.dart';
import '../domain/health_status.dart';

const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

/// 体調のようす（S-30 のグラフの下。F-ST-02）。選んだ猫・日の各項目を、ふだんの範囲と並べる
class HealthSection extends ConsumerStatefulWidget {
  const HealthSection({
    super.key,
    required this.catId,
    required this.today,
    this.day,
  });

  final String catId;
  final DateTime today;

  /// 初めに出す日（いつもとの差の通知から開くとき）。なければきのう
  final DateTime? day;

  @override
  ConsumerState<HealthSection> createState() => _HealthSectionState();
}

class _HealthSectionState extends ConsumerState<HealthSection> {
  late final DateTime _today = DateTime(
    widget.today.year,
    widget.today.month,
    widget.today.day,
  );
  late DateTime _day = _initialDay();

  DateTime _initialDay() {
    final d = widget.day;
    if (d == null || d.isAfter(_today)) {
      return _today.subtract(const Duration(days: 1));
    }
    return DateTime(d.year, d.month, d.day);
  }

  void _move(int days) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = (ref.watch(filterCatsProvider).value ?? const [])
        .where((c) => c.id == widget.catId)
        .firstOrNull;
    final method =
        ref.watch(notificationSettingsProvider).value?.method ??
        AnomalyMethod.statistical;
    // ふだんの28日（今日は前日より前）と、体重の比べる分（さらに28日）を読む
    final entries =
        ref
            .watch(
              rangeRecordsProvider((
                from: _day.subtract(const Duration(days: usualDays * 2 + 1)),
                to: DateTime(_day.year, _day.month, _day.day + 1),
                catId: widget.catId,
              )),
            )
            .value ??
        const [];
    final status = cat == null
        ? const HealthStatus()
        : healthStatus(
            cat: AnomalyCat(
              id: cat.id,
              name: cat.name,
              thresholds: cat.anomalyThresholds,
            ),
            records: [
              for (final e in entries)
                AnomalyRecord(
                  catId: e.catId,
                  kind: e.kind,
                  recordedAt: e.recordedAt,
                  valueNumber: e.valueNumber,
                ),
            ],
            method: method,
            day: _day,
            now: widget.today,
          );
    final outliers = [
      for (final i in status.items)
        if (i.outlier != null) i,
    ];
    final normal = [
      for (final i in status.items)
        if (i.outlier == null) i,
    ];
    final usualLabel = method == AnomalyMethod.threshold ? 'しきい値' : 'ふだん';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('体調のようす', style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: '前の日',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _move(-1),
            ),
            Text('${_day.month}/${_day.day}(${_weekdays[_day.weekday - 1]})'),
            IconButton(
              tooltip: '次の日',
              icon: const Icon(Icons.chevron_right),
              onPressed: _day == _today ? null : () => _move(1),
            ),
          ],
        ),
        if (status.daysLeft > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'まだ判定できません（記録が$minRecordDays日分たまると判定します。'
              'あと${status.daysLeft}日）',
            ),
          )
        else ...[
          Text(
            outliers.isEmpty ? '外れ値はありません' : '外れ値 ${outliers.length}個',
            style: theme.textTheme.titleSmall,
          ),
          if (_day == _today)
            const Text('きょうは途中なので、多すぎだけを見ます')
          else if (!status.recorded)
            const Text('この日は記録がないため、少なすぎは見ません'),
          if (outliers.isNotEmpty) ...[
            const _Heading('外れ値'),
            for (final i in outliers) _HealthTile(i, usualLabel: usualLabel),
          ],
          const _Heading('範囲内'),
          for (final i in normal) _HealthTile(i, usualLabel: usualLabel),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// 範囲の文（例：2〜4回、2回以上、4回以下）
String rangeText(num? min, num? max, String unit) {
  String f(num v) => unit == 'kg' ? v.toStringAsFixed(1) : '$v';
  return switch ((min, max)) {
    (final lo?, final hi?) when f(lo) == f(hi) => '${f(lo)}$unit',
    (final lo?, final hi?) => '${f(lo)}〜${f(hi)}$unit',
    (final lo?, null) => '${f(lo)}$unit以上',
    (null, final hi?) => '${f(hi)}$unit以下',
    _ => '',
  };
}

class _HealthTile extends StatelessWidget {
  const _HealthTile(this.item, {required this.usualLabel});

  final HealthItem item;
  final String usualLabel;

  @override
  Widget build(BuildContext context) {
    final weight = item.kind == 'weight';
    final unit = weight ? 'kg' : '回';
    final label = weight ? '体重' : RecordKind.values.byName(item.kind).label;
    final value = switch (item.value) {
      null => '記録なし',
      final v when weight => '${v.toStringAsFixed(1)}kg',
      final v => '$v回',
    };
    final d = item.weightDay;
    final when = d == null ? '' : '（${d.month}/${d.day} の記録）';
    final usual = switch (item) {
      HealthItem(value: null) => '',
      HealthItem(hasRule: false) when weight => '比べる記録がありません',
      HealthItem(hasRule: false) => 'しきい値なし',
      _ => '$usualLabel ${rangeText(item.min, item.max, unit)}',
    };
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('$label　$value$when'),
      subtitle: usual.isEmpty ? null : Text(usual),
      trailing: switch (item.outlier) {
        AnomalyDirection.low => Text(
          weight ? '減っています' : '少なめ',
          style: TextStyle(color: error),
        ),
        AnomalyDirection.high => Text(
          weight ? '増えています' : '多め',
          style: TextStyle(color: error),
        ),
        null => null,
      },
    );
  }
}
