/// 記録の検索（F-VW-03、画面設計書 S-23）の条件と、当たった言葉の扱い
library;

/// 検索の条件。どれも空（null・空の文字）なら、その条件では絞らない
///
/// Dart の record にして、同じ条件なら同じもの（==）として扱えるようにする
/// （Riverpod の family の鍵に使い、同じ条件で探し直さないため）
typedef SearchQuery = ({
  String words,
  String? recordTypeId,
  String? catId,
  DateTime? from,
  DateTime? to,
});

/// 条件なしの検索（新しい順にすべて）
const SearchQuery emptyQuery = (
  words: '',
  recordTypeId: null,
  catId: null,
  from: null,
  to: null,
);

/// メモの言葉を空白（半角・全角）で分ける。空の言葉は除く
List<String> splitWords(String text) => [
  for (final w in text.split(RegExp(r'[\s　]+')))
    if (w.isNotEmpty) w,
];

/// メモがすべての言葉を含むか（英字の大文字と小文字は区別しない）。言葉がなければ真
bool matchesWords(String? memo, List<String> words) {
  if (words.isEmpty) {
    return true;
  }
  if (memo == null) {
    return false;
  }
  final lower = memo.toLowerCase();
  return words.every((w) => lower.contains(w.toLowerCase()));
}

/// 期間に入るか。from と to は日付で、どちらも含む（to の日の終わりまで）
bool inPeriod(DateTime at, DateTime? from, DateTime? to) {
  if (from != null && at.isBefore(DateTime(from.year, from.month, from.day))) {
    return false;
  }
  if (to != null && !at.isBefore(DateTime(to.year, to.month, to.day + 1))) {
    return false;
  }
  return true;
}

/// メモの中で言葉が当たった範囲（start 以上 end 未満）。重なりと隣り合いはまとめ、前から順に返す
List<({int start, int end})> matchRanges(String text, List<String> words) {
  final lower = text.toLowerCase();
  final ranges = <({int start, int end})>[];
  for (final w in words) {
    final key = w.toLowerCase();
    var i = lower.indexOf(key);
    while (i >= 0) {
      ranges.add((start: i, end: i + key.length));
      i = lower.indexOf(key, i + 1);
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({int start, int end})>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: r.end > last.end ? r.end : last.end));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// 当たった言葉の前に残す文字の数（メモの後ろで当たったとき）
const snippetLead = 10;

/// 一覧に出すメモの始まりの位置。最初に当たった言葉が後ろ（snippetLead より後）にあれば、
/// その少し前から出す（2行に収めて省略しても、当たった言葉が見えるように。S-23）
int snippetStart(List<({int start, int end})> ranges) {
  if (ranges.isEmpty || ranges.first.start <= snippetLead) {
    return 0;
  }
  return ranges.first.start - snippetLead;
}
