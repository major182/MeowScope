import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../records/presentation/record_format.dart';
import '../../records/domain/record_kind.dart';
import '../domain/calendar_month.dart';
import 'calendar_providers.dart';

/// 日別一覧の見出し。「<」「>」で前後の日へ移動する
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '前の日',
          onPressed: () =>
              onChanged(DateTime(day.year, day.month, day.day - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${day.month}月 ${day.day}日'),
        IconButton(
          tooltip: '次の日',
          onPressed: () =>
              onChanged(DateTime(day.year, day.month, day.day + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// 1日の記録を時刻の順に並べる。押すと記録の詳細へ進む
class DayRecordList extends ConsumerWidget {
  const DayRecordList({super.key, required this.day, required this.catId});

  final DateTime day;
  final String? catId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = dateOnly(day);
    final entries =
        ref
            .watch(
              rangeRecordsProvider((
                from: start,
                to: DateTime(start.year, start.month, start.day + 1),
                catId: catId,
              )),
            )
            .value ??
        const [];
    if (entries.isEmpty) {
      return const Center(child: Text('この日の記録はありません'));
    }
    return ListView(
      children: [
        for (final e in entries)
          ListTile(
            leading: Text(formatTime(e.recordedAt)),
            title: Text('${e.catName}　${e.typeName}'),
            trailing: e.hasMemo
                ? const Image(
                    image: AssetImage(memoAsset),
                    width: 24,
                    height: 24,
                    semanticLabel: 'メモあり',
                  )
                : null,
            onTap: () => context.push('/records/${e.id}'),
          ),
      ],
    );
  }
}

/// 日別一覧（S-21）。狭い幅でカレンダーの日を押したときに開く
class DayListScreen extends StatefulWidget {
  const DayListScreen({super.key, required this.day, this.catId});

  final DateTime day;
  final String? catId;

  @override
  State<DayListScreen> createState() => _DayListScreenState();
}

class _DayListScreenState extends State<DayListScreen> {
  late DateTime _day = dateOnly(widget.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DayHeader(day: _day, onChanged: (d) => setState(() => _day = d)),
      ),
      body: DayRecordList(day: _day, catId: widget.catId),
    );
  }
}
