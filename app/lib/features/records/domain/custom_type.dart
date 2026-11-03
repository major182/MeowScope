/// 独自の項目に選べるアイコン（F-RC-05）。
/// 保存する値は name で、イラストが届いたら assets/icons/{name}.png に差し替える
enum CustomIcon {
  hospital('custom_hospital', '通院'),
  toy('custom_toy', 'おもちゃ'),
  nail('custom_nail', '爪切り'),
  bath('custom_bath', 'お風呂'),
  star('custom_star', '星');

  const CustomIcon(this.value, this.label);

  /// record_types.icon に保存する値
  final String value;

  /// 選ぶときに出す名前
  final String label;

  /// 保存した値から戻す。知らない値や空は null
  static CustomIcon? parse(String? value) {
    for (final i in values) {
      if (i.value == value) {
        return i;
      }
    }
    return null;
  }
}

/// 項目の名前の長さの上限
const maxTypeNameLength = 20;

/// 項目の名前を確かめる。existing は同じおうちの他の項目の名前
String? validateTypeName(String? text, Iterable<String> existing) {
  final name = text?.trim() ?? '';
  if (name.isEmpty) {
    return '名前を入力してください';
  }
  if (name.length > maxTypeNameLength) {
    return '$maxTypeNameLength文字以内で入力してください';
  }
  if (existing.contains(name)) {
    return '同じ名前の項目があります';
  }
  return null;
}
