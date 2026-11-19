import 'record_kind.dart';

/// 量（records.level の値）
enum RecordLevel {
  little('少し'),
  normal('普通'),
  much('多い');

  const RecordLevel(this.label);

  final String label;

  /// 保存した値から戻す。知らない値は null
  static RecordLevel? parse(String? value) {
    for (final l in values) {
      if (l.name == value) {
        return l;
      }
    }
    return null;
  }
}

/// 量を入力する項目か。薬・体重・ブラシ・病院以外
bool hasLevel(String kind) =>
    kind != RecordKind.vet.name &&
    kind != RecordKind.medicine.name &&
    kind != RecordKind.weight.name &&
    kind != RecordKind.brushing.name;

/// 病院の名前と次の予定日を入力する項目か（F-MD-01）
bool hasVetDetail(String kind) => kind == RecordKind.vet.name;

/// 体重を入力する項目か
bool hasWeight(String kind) => kind == RecordKind.weight.name;

/// 体重の範囲（kg）
const minWeight = 0.1;
const maxWeight = 30.0;

/// メモの長さの上限
const maxMemoLength = 1000;

/// 体重の入力を確かめる。空は未入力として null を返す
String? validateWeight(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  final number = double.tryParse(value);
  if (number == null) {
    return '数字で入力してください';
  }
  if (number < minWeight || number > maxWeight) {
    return '$minWeight〜${maxWeight.toStringAsFixed(0)} kg で入力してください';
  }
  return null;
}

/// 記録の日時を確かめる。未来は受け付けない
String? validateRecordedAt(DateTime value, DateTime now) =>
    value.isAfter(now) ? '未来の日時は選べません' : null;

/// カレンダーの日付から記録を始められるか（F-VW-06、BR-35）。未来の日は選べない
bool canRecordOn(DateTime day, DateTime now) =>
    !DateTime(day.year, day.month, day.day).isAfter(now);

/// カレンダーの日付から記録するときの日時の既定（BR-35）。
/// 選んだ日に今の時刻（時・分）を合わせる。今日なら今より後にならないよう、今にそろえる
DateTime defaultRecordedAt(DateTime day, DateTime now) {
  final at = DateTime(day.year, day.month, day.day, now.hour, now.minute);
  return at.isAfter(now) ? now : at;
}
