import '../../records/domain/record_kind.dart';

/// カレンダーの週の始まり（F-VW-04）
enum WeekStart {
  sunday,
  monday;

  /// 保存した値から戻す。知らない値や空は既定の日曜
  static WeekStart parse(String? value) =>
      value == monday.name ? monday : sunday;

  /// 曜日の見出し（週の始まりから順に）
  List<String> get labels => this == sunday
      ? const ['日', '月', '火', '水', '木', '金', '土']
      : const ['月', '火', '水', '木', '金', '土', '日'];
}

/// カレンダーの行と列の数（6行7列）
const calendarDays = 42;

/// その月を含む6週間（42日）の日付を、週の始まりから並べる
List<DateTime> monthGrid(DateTime month, WeekStart start) {
  final first = DateTime(month.year, month.month);
  // DateTime.weekday は 月曜=1 … 日曜=7
  final offset = start == WeekStart.sunday
      ? first.weekday % 7
      : first.weekday - 1;
  return [
    for (var i = 0; i < calendarDays; i++)
      DateTime(first.year, first.month, first.day - offset + i),
  ];
}

/// 日付だけにする（時刻を落とす）
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 同じ日か
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// カレンダーのセルに出す印（イラストの場所と、読み上げに使う名前）
typedef CalendarMark = ({String asset, String label});

/// 標準の項目の並び順（印を並べる順）。独自の項目は後ろ
int kindOrder(String kind) {
  final i = RecordKind.values.indexWhere((k) => k.name == kind);
  return i < 0 ? RecordKind.values.length : i;
}
