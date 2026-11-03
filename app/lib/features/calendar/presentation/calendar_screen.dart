import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/main_shell.dart';
import '../../../core/providers.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../records/data/record_repository.dart';
import '../domain/calendar_month.dart';
import 'calendar_providers.dart';
import 'day_records.dart';

/// カレンダー（S-20）。広い幅では日別一覧（S-21）を右に並べる
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.today});

  /// 今日の日付。テストで差し替える
  final DateTime? today;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final DateTime _today = dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;
  String? _catId;

  void _moveMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _selectDay(DateTime day, bool wide) {
    if (wide) {
      setState(() {
        _selected = day;
        // 日別一覧で別の月へ移ったら、カレンダーも合わせる
        _month = DateTime(day.year, day.month);
      });
      return;
    }
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    context.push(
      Uri(
        path: '/days/$date',
        queryParameters: _catId == null ? null : {'cat': _catId},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final weekStart = ref.watch(weekStartProvider).value ?? WeekStart.sunday;
    final days = monthGrid(_month, weekStart);
    final entries =
        ref
            .watch(
              rangeRecordsProvider((
                from: days.first,
                to: DateTime(
                  days.last.year,
                  days.last.month,
                  days.last.day + 1,
                ),
                catId: _catId,
              )),
            )
            .value ??
        const [];
    final calendar = Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 12),
            CatFilter(
              selected: _catId,
              onChanged: (id) => setState(() => _catId = id),
            ),
            const Spacer(),
            IconButton(
              tooltip: '前の月',
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_month.year}年${_month.month}月'),
            IconButton(
              tooltip: '次の月',
              onPressed: () => _moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in weekStart.labels)
              Expanded(child: Center(child: Text(label))),
          ],
        ),
        Expanded(
          child: _MonthGrid(
            days: days,
            month: _month,
            today: _today,
            selected: wide ? _selected : null,
            marks: dayMarks(entries),
            onTap: (d) => _selectDay(d, wide),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー')),
      body: wide
          ? Row(
              children: [
                Expanded(child: calendar),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      DayHeader(
                        day: _selected,
                        onChanged: (d) => _selectDay(d, true),
                      ),
                      Expanded(
                        child: DayRecordList(day: _selected, catId: _catId),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : calendar,
    );
  }
}

/// 日ごとに出す印（項目の印を標準の順に、メモがあれば最後にメモの印）
Map<DateTime, List<String>> dayMarks(List<RecordEntry> entries) {
  final byDay = <DateTime, List<RecordEntry>>{};
  for (final e in entries) {
    byDay.putIfAbsent(dateOnly(e.recordedAt), () => []).add(e);
  }
  return {
    for (final MapEntry(key: day, value: list) in byDay.entries)
      day: [
        ...{
          for (final e in [
            ...list,
          ]..sort((a, b) => kindOrder(a.kind).compareTo(kindOrder(b.kind))))
            kindMark(e.kind, e.typeName),
        },
        if (list.any((e) => e.hasMemo)) memoMark,
      ],
  };
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.month,
    required this.today,
    required this.selected,
    required this.marks,
    required this.onTap,
  });

  final List<DateTime> days;
  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final Map<DateTime, List<String>> marks;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in days.skip(row * 7).take(7))
                  Expanded(
                    child: InkWell(
                      key: ValueKey('day-${day.month}-${day.day}'),
                      onTap: () => onTap(day),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          color: selected != null && isSameDay(day, selected!)
                              ? scheme.primaryContainer
                              : null,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: day.month != month.month
                                    ? scheme.outline
                                    : null,
                                fontWeight: isSameDay(day, today)
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: ClipRect(
                                child: Wrap(
                                  children: [
                                    for (final m in marks[day] ?? const [])
                                      Text(
                                        m,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
