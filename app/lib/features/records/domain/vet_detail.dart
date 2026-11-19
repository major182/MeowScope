/// 病院の記録の追加情報（records.detail。F-MD-01、DB 設計書 4章）
///
/// `{"hospital": "○○動物病院", "nextDate": "2026-12-01"}` の形。どちらも任意で、なければキーを入れない
library;

import 'dart:convert';

/// 病院の名前の長さの上限
const maxHospitalLength = 50;

/// 病院の記録の追加情報
class VetDetail {
  const VetDetail({this.hospital, this.nextDate});

  /// 病院の名前
  final String? hospital;

  /// 次の予定日（日付だけ）
  final DateTime? nextDate;

  bool get isEmpty => hospital == null && nextDate == null;

  /// 保存した detail（JSON の文字）から読む。壊れた値・形の違う値は読めるところだけ使う
  static VetDetail parse(String? json) {
    if (json == null) {
      return const VetDetail();
    }
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const VetDetail();
    }
    if (decoded is! Map) {
      return const VetDetail();
    }
    final hospital = decoded['hospital'];
    final next = decoded['nextDate'];
    final date = next is String ? DateTime.tryParse(next) : null;
    return VetDetail(
      hospital: hospital is String && hospital.trim().isNotEmpty
          ? hospital.trim()
          : null,
      nextDate: date == null ? null : DateTime(date.year, date.month, date.day),
    );
  }

  /// 保存する detail（JSON の文字）。何もなければ null（detail を空にする）
  String? encode() {
    if (isEmpty) {
      return null;
    }
    final d = nextDate;
    return jsonEncode({
      'hospital': ?hospital,
      if (d != null)
        'nextDate':
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    });
  }
}

/// 病院の名前の入力を確かめる。空は未入力として null
String? validateHospital(String? text) {
  final value = text?.trim() ?? '';
  return value.length > maxHospitalLength
      ? '$maxHospitalLength文字以内で入力してください'
      : null;
}

/// 病院の名前の候補（同じおうちで前に入れた名前）。新しく使った順に、重なりを除いて並べる
///
/// [details] は記録の新しい順に並んだ detail
List<String> hospitalSuggestions(Iterable<String?> details) {
  final seen = <String>{};
  return [
    for (final d in details)
      if (VetDetail.parse(d).hospital case final name? when seen.add(name))
        name,
  ];
}

/// 候補を、入力した文字を含むものに絞る（英字の大文字と小文字は区別しない）。空なら全部
List<String> filterSuggestions(List<String> names, String input) {
  final key = input.trim().toLowerCase();
  if (key.isEmpty) {
    return names;
  }
  return [
    for (final n in names)
      if (n.toLowerCase().contains(key)) n,
  ];
}
