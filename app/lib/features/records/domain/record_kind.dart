/// 標準の記録項目（F-RC-01）。おうちを作るときに、この順で登録する
enum RecordKind {
  food('ご飯', 'food'),
  water('水', 'water'),
  medicine('薬', 'medicine'),
  urine('おしっこ', 'pee'),
  stool('うんち', 'poop'),
  vomit('吐いた', 'vomit'),
  weight('体重', 'weight'),
  brushing('ブラッシング', 'brushing');

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
  final known = RecordKind.values.any((k) => k.icon == icon);
  return known ? 'assets/icons/$icon.png' : null;
}
