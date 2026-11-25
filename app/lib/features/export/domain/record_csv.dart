/// 記録の CSV（F-EX-01、BR-41。画面設計書 S-52）
///
/// 1行に記録を1件とし、Excel で開いても文字化けしないよう、先頭に BOM を付けた UTF-8 にする。
/// 改行は Excel の既定に合わせて CRLF にする（RFC 4180）
library;

import '../../records/data/record_repository.dart';
import '../../records/domain/record_detail.dart';
import '../../records/domain/vet_detail.dart';

/// 先頭に付ける印（BOM）。Excel はこれを見て UTF-8 と判断する
const csvBom = '﻿';

/// 見出しの行
const csvHeader = [
  '日付',
  '時刻',
  '猫',
  '項目',
  '量',
  '体重（kg）',
  '病院',
  '次の予定日',
  'メモ',
  '記録した人',
  '写真',
];

/// 出す記録の条件。null は「すべて」。期間は日付だけを見て、両端の日を含む
typedef CsvFilter = ({
  DateTime? from,
  DateTime? to,
  Set<String>? catIds,
  Set<String>? recordTypeIds,
});

/// [filter] の期間を、記録の読み出しに使う「from 以上 to 未満」の日時にする。
/// 全期間のときは、記録がありうる範囲の全体にする
({DateTime from, DateTime to}) csvRange(CsvFilter filter, DateTime now) {
  final from = filter.from;
  final to = filter.to;
  return (
    from: from == null
        ? DateTime(2000)
        : DateTime(from.year, from.month, from.day),
    // 終わりの日を含めるため、その次の日の0時まで。全期間なら明日の0時まで（未来の記録はない）
    to: to == null
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(to.year, to.month, to.day + 1),
  );
}

/// [records] のうち、猫と項目の条件に合うもの（CSV に出す記録）
List<RecordEntry> filterCsvRecords(
  List<RecordEntry> records,
  CsvFilter filter,
) {
  final cats = filter.catIds;
  final types = filter.recordTypeIds;
  return [
    for (final r in records)
      if ((cats == null || cats.contains(r.catId)) &&
          (types == null || types.contains(r.recordTypeId)))
        r,
  ];
}

/// [records]（古い順）のうち、猫と項目の条件に合うものを CSV にする
String buildRecordCsv(List<RecordEntry> records, CsvFilter filter) {
  final rows = [
    csvHeader,
    for (final r in filterCsvRecords(records, filter)) _row(r),
  ];
  return '$csvBom${rows.map((cells) => cells.map(csvCell).join(',')).join('\r\n')}\r\n';
}

List<String> _row(RecordEntry r) {
  final at = r.recordedAt.toLocal();
  final vet = hasVetDetail(r.kind) ? VetDetail.parse(r.detail) : null;
  final next = vet?.nextDate;
  return [
    _date(at),
    '${_two(at.hour)}:${_two(at.minute)}',
    r.catName,
    r.typeName,
    RecordLevel.parse(r.level)?.label ?? '',
    hasWeight(r.kind) && r.valueNumber != null ? '${r.valueNumber}' : '',
    vet?.hospital ?? '',
    next == null ? '' : _date(next),
    r.memo ?? '',
    r.authorName,
    r.hasPhoto ? 'あり' : '',
  ];
}

/// 1つの欄。カンマ・引用符・改行を含むときは引用符で囲み、中の引用符は2つにする（RFC 4180）。
///
/// `=` `+` `-` `@` などで始まる文字は、Excel が式として動かしてしまう（CSV インジェクション）。
/// メモなど利用者が入れた文字にありうるので、先頭に `'` を付けて文字として扱わせる
String csvCell(String value) {
  var text = value;
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(RegExp('[",\r\n]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// 保存の画面に出す、ファイルの名前の案（meowscope_20261125.csv）
String suggestedCsvName(DateTime now) =>
    'meowscope_${now.year}${_two(now.month)}${_two(now.day)}.csv';

String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _two(int n) => n.toString().padLeft(2, '0');
