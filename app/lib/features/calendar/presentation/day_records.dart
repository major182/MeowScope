import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/today.dart';
import '../../records/domain/record_detail.dart';
import '../../records/presentation/record_format.dart';
import 'day_record_add.dart';
import '../../icons/icon_avatar.dart';
import '../../records/domain/record_kind.dart';
import '../domain/calendar_month.dart';
import 'calendar_providers.dart';

/// 日別一覧の「記録を追加」（F-VW-06）。未来の日には出さない（BR-35）
class AddDayRecordButton extends ConsumerWidget {
  const AddDayRecordButton({
    super.key,
    required this.day,
    this.compact = false,
  });

  final DateTime day;

  /// 見出しの横（狭い画面の上部）に置くときは、日付と並んで収まるよう
  /// アイコンだけにする（説明はマウスを重ねたときと読み上げで出す）
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 開いたまま日付が変わっても合うよう、今日の流れを見張る
    ref.watch(todayProvider);
    if (!canRecordOn(day, ref.watch(nowProvider)())) {
      return const SizedBox.shrink();
    }
    void open() => context.push(dayRecordAddPath(day));
    if (compact) {
      return IconButton(
        tooltip: '記録を追加',
        onPressed: open,
        icon: const Icon(Icons.add),
      );
    }
    return TextButton.icon(
      onPressed: open,
      icon: const Icon(Icons.add),
      label: const Text('記録を追加'),
    );
  }
}

/// 日別一覧の見出し。「<」「>」で前後の日へ移動する
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    // 狭い画面の上部では、戻るボタンと「記録を追加」の間に収める。
    // 幅が足りないときだけ全体を縮め、はみ出さないようにする（足りるときは元の大きさ）
    return FittedBox(fit: BoxFit.scaleDown, child: _row());
  }

  Widget _row() {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
            title: Align(
              alignment: Alignment.centerLeft,
              child: IconLabel(
                icon: e.catIcon,
                text: '${e.catName}　${e.typeName}',
              ),
            ),
            // メモと写真の印（S-21）。写真の印はイラストがないので、標準のアイコンを使う
            trailing: e.hasMemo || e.hasPhoto
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (e.hasMemo)
                        const Image(
                          image: AssetImage(memoAsset),
                          width: 24,
                          height: 24,
                          semanticLabel: 'メモあり',
                        ),
                      if (e.hasPhoto)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 22,
                            semanticLabel: '写真あり',
                          ),
                        ),
                    ],
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
        actions: [AddDayRecordButton(day: _day, compact: true)],
      ),
      body: DayRecordList(day: _day, catId: widget.catId),
    );
  }
}
