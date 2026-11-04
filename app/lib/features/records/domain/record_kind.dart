import 'custom_type.dart';

/// 標準の記録項目（F-RC-01）。おうちを作るときに、この順で登録する
enum RecordKind {
  food('ご飯', 'food'),
  water('水', 'water'),
  medicine('薬', 'medicine'),
  urine('おしっこ', 'pee'),
  stool('うんち', 'poop'),
  vomit('吐いた', 'vomit'),
  weight('体重', 'weight'),
  brushing('ブラシ', 'brushing');

  const RecordKind(this.label, this.icon);

  /// 画面に出す名前
  final String label;

  /// `assets/icons/` のイラストの名前
  final String icon;

  /// 独自の項目を表す種類の値
  static const custom = 'custom';
}

/// アイコンの名前からイラストの場所を返す。イラストがなければ null
String? iconAsset(String? icon) {
  if (icon == null) {
    return null;
  }
  final known =
      RecordKind.values.any((k) => k.icon == icon) ||
      CustomIcon.parse(icon) != null;
  return known ? 'assets/icons/$icon.png' : null;
}

/// 独自の項目でイラストが見つからないときに使う「その他」のイラスト
final fallbackIconAsset = 'assets/icons/${CustomIcon.other.value}.png';

/// カレンダーのセルに出すイラストの場所。
/// 標準の項目はカレンダー用の小さなイラスト（cal_*）、独自の項目は選んだイラスト
String calendarAsset(String kind, String? icon) {
  for (final k in RecordKind.values) {
    if (k.name == kind) {
      return 'assets/icons/cal_${k.icon}.png';
    }
  }
  return iconAsset(icon) ?? fallbackIconAsset;
}

/// メモありの印のイラスト
const memoAsset = 'assets/icons/cal_memo.png';
