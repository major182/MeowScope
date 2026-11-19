import 'custom_type.dart';

/// 標準の記録項目（F-RC-01）。おうちを作るときに、この順で登録する。
/// 病院（vet）は Ver.1.3.0 から（F-MD-01）。今あるおうちにはサーバーが足す（BR-37）
enum RecordKind {
  food('ご飯', 'food'),
  water('水', 'water'),
  medicine('薬', 'medicine'),
  urine('おしっこ', 'pee'),
  stool('うんち', 'poop'),
  vomit('吐いた', 'vomit'),
  weight('体重', 'weight'),
  brushing('ブラシ', 'brushing'),
  vet('病院', 'vet');

  const RecordKind(this.label, this.icon);

  /// 画面に出す名前
  final String label;

  /// `assets/icons/` のイラストの名前
  final String icon;

  /// 独自の項目を表す種類の値
  static const custom = 'custom';

  /// record_types.icon に保存する値。病院は、古いアプリでも通院のイラストで出るよう
  /// custom_vet を保存する（サーバーの V9 と同じ）。画面の絵は種類から決める（[typeIconValue]）
  String get storedIcon => this == vet ? 'custom_vet' : icon;
}

/// 画面に出す項目の絵の名前。標準の項目は種類から決め、独自の項目は保存した値を使う
///
/// なぜ：病院は保存した値（custom_vet）と画面の絵（vet）が違うため
String? typeIconValue(String kind, String? icon) {
  for (final k in RecordKind.values) {
    if (k.name == kind) {
      return k.icon;
    }
  }
  return icon;
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
  // 病院のカレンダー用の小さなイラストはないので、通院のイラストを使う（予定の印と同じ）
  if (kind == RecordKind.vet.name) {
    return vetCalendarAsset;
  }
  for (final k in RecordKind.values) {
    if (k.name == kind) {
      return 'assets/icons/cal_${k.icon}.png';
    }
  }
  return iconAsset(icon) ?? fallbackIconAsset;
}

/// 病院の記録と、次の予定日の印のイラスト（カレンダー。F-MD-01）
const vetCalendarAsset = 'assets/icons/custom_vet.png';

/// メモありの印のイラスト
const memoAsset = 'assets/icons/cal_memo.png';
