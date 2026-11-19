import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/main_shell.dart';
import '../../../core/providers.dart';
import '../../../core/today.dart';
import '../../../core/db/app_database.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../notifications/domain/birthday_plan.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/record_kind.dart';
import '../../records/domain/vet_detail.dart';
import '../../records/presentation/record_providers.dart';
import 'day_record_add.dart';
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

  /// 誕生日の印を出す猫の生年月日（F-VW-05、BR-32）。お別れの猫と生年月日のない猫は除き、1匹を選んでいればその猫だけ
  List<DateTime> _birthdays(List<CatRow>? cats) => [
    for (final c in cats ?? const <CatRow>[])
      if (c.status != 'farewell' && (_catId == null || c.id == _catId))
        if (c.birthDate case final birth?) birthDateOf(birth),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final weekStart = ref.watch(weekStartProvider).value ?? WeekStart.sunday;
    final days = monthGrid(_month, weekStart);
    // 開いたまま日付が変わったら、「今日」の印を新しい日に移す（B-3）
    final today = widget.today ?? ref.watch(todayProvider).value ?? _today;
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
            today: today,
            selected: wide ? _selected : null,
            marks: dayMarks(entries),
            birthdays: _birthdays(ref.watch(filterCatsProvider).value),
            plans: vetPlanDays(
              ref.watch(vetRecordsProvider).value ?? const [],
              today,
              catId: _catId,
            ),
            onTap: (d) => _selectDay(d, wide),
            // 日付の長押しで、その日の記録を始める（F-VW-06）。未来の日は何もしない（BR-35）
            onLongPress: (d) async {
              if (d.isAfter(today)) {
                return;
              }
              final saved = await context.push<bool>(dayRecordAddPath(d));
              // 保存したら、その日の日別一覧を開く（狭い幅は S-21 へ進み、広い幅は右の一覧をその日にする。#272）
              if (saved == true && mounted) {
                _selectDay(d, wide);
              }
            },
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          // 記録の検索（S-23。F-VW-03）
          IconButton(
            tooltip: '記録の検索',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: AddDayRecordButton(day: _selected),
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

/// 日ごとに出す印。項目ごとに1つを標準の順に並べ（独自の項目は後ろ）、
/// メモがあれば最後にメモの印を付ける
Map<DateTime, List<CalendarMark>> dayMarks(List<RecordEntry> entries) {
  final byDay = <DateTime, List<RecordEntry>>{};
  for (final e in entries) {
    byDay.putIfAbsent(dateOnly(e.recordedAt), () => []).add(e);
  }
  return {
    for (final MapEntry(key: day, value: list) in byDay.entries)
      day: [
        // 同じ項目は1つにまとめる（sort は同じ順位なら元の順を保つ）
        ...{
          for (final e in [
            ...list,
          ]..sort((a, b) => kindOrder(a.kind).compareTo(kindOrder(b.kind))))
            e.recordTypeId: (
              asset: calendarAsset(e.kind, e.typeIcon),
              label: e.typeName,
            ),
        }.values,
        if (list.any((e) => e.hasMemo)) (asset: memoAsset, label: 'メモあり'),
      ],
  };
}

/// 病院の次の予定日の印を出す日（F-MD-01、BR-37）。今日と未来の日だけ。catId を渡すとその猫だけ
Set<DateTime> vetPlanDays(
  List<RecordEntry> vetRecords,
  DateTime today, {
  String? catId,
}) => {
  for (final e in vetRecords)
    if (catId == null || e.catId == catId)
      if (VetDetail.parse(e.detail).nextDate case final d?
          when !d.isBefore(dateOnly(today)))
        d,
};

/// 月の表の1行の高さの下限。日付（1行）と、その下の記録の印（14px）が切れずに入る高さ
const calendarMinRowHeight = 44.0;

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.month,
    required this.today,
    required this.selected,
    required this.marks,
    required this.onTap,
    required this.onLongPress,
    this.birthdays = const [],
    this.plans = const {},
  });

  final List<DateTime> days;
  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final Map<DateTime, List<CalendarMark>> marks;

  /// 誕生日の印を出す猫の生年月日
  final List<DateTime> birthdays;

  /// 病院の次の予定日（印を出す日）
  final Set<DateTime> plans;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime> onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ふだんは6行で高さを分け合う。横向きなど高さが足りず1行が低くなりすぎると、
        // 日付の下の記録の印が切れるので、そのときは行を下限の高さにしてスクロールする（#248）
        if (constraints.maxHeight / 6 >= calendarMinRowHeight) {
          return Column(
            children: [
              for (var row = 0; row < 6; row++)
                Expanded(child: _row(context, row)),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              for (var row = 0; row < 6; row++)
                SizedBox(
                  height: calendarMinRowHeight,
                  child: _row(context, row),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 1週間（7日）の行
  Widget _row(BuildContext context, int row) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days.skip(row * 7).take(7))
          Expanded(
            child: InkWell(
              key: ValueKey('day-${day.month}-${day.day}'),
              onTap: () => onTap(day),
              onLongPress: () => onLongPress(day),
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
                    Row(
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
                        const Spacer(),
                        // 病院の予定は、誕生日と同じく右上に出す（予定の印。S-20）
                        if (plans.contains(dateOnly(day)))
                          Image.asset(
                            vetCalendarAsset,
                            width: 14,
                            height: 14,
                            semanticLabel: '病院の予定',
                          ),
                        // 誕生日はセルの右上に印を出す。イラストがないので標準のケーキのアイコンを使う
                        if (birthdays.any((b) => isBirthday(b, day)))
                          Icon(
                            Icons.cake_outlined,
                            size: 14,
                            color: scheme.primary,
                            semanticLabel: '誕生日',
                          ),
                      ],
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Wrap(
                          spacing: 1,
                          runSpacing: 1,
                          children: [
                            for (final m in marks[day] ?? const [])
                              Image.asset(
                                m.asset,
                                width: 14,
                                height: 14,
                                semanticLabel: m.label,
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
    );
  }
}
