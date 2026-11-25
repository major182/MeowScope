import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/export/domain/record_csv.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

/// 記録の CSV（F-EX-01、BR-41）
void main() {
  RecordEntry entry(
    String id, {
    String catId = 'c1',
    String catName = 'ミケ',
    String typeId = 't1',
    String typeName = 'ご飯',
    String kind = 'food',
    DateTime? at,
    String? level,
    double? weight,
    String? memo,
    String? detail,
    bool photo = false,
  }) => RecordEntry(
    id: id,
    recordedAt: at ?? DateTime(2026, 11, 5, 8, 3),
    catName: catName,
    typeName: typeName,
    catId: catId,
    kind: kind,
    hasMemo: memo != null,
    recordTypeId: typeId,
    level: level,
    valueNumber: weight,
    memo: memo,
    detail: detail,
    authorName: 'はる',
    hasPhoto: photo,
  );

  const all = (from: null, to: null, catIds: null, recordTypeIds: null);

  List<String> lines(String csv) => csv.substring(1).split('\r\n');

  group('UT-EX-01 CSV の形', () {
    test('先頭に BOM、見出しの行、改行は CRLF、最後も改行で終わる。記録がなければ見出しだけ', () {
      final csv = buildRecordCsv(const [], all);
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(csv, '﻿日付,時刻,猫,項目,量,体重（kg）,病院,次の予定日,メモ,記録した人,写真\r\n');
    });

    test('1行に記録1件。日時は端末の時刻、量は日本語、体重・病院・写真を出す', () {
      final csv = buildRecordCsv([
        entry('r1', level: 'little', memo: '完食', photo: true),
        entry(
          'r2',
          typeId: 't2',
          typeName: '体重',
          kind: 'weight',
          weight: 4.2,
          at: DateTime(2026, 11, 6, 21, 0),
        ),
        entry(
          'r3',
          typeId: 't3',
          typeName: '病院',
          kind: 'vet',
          detail: '{"hospital": "みどり動物病院", "nextDate": "2026-12-01"}',
        ),
      ], all);
      expect(lines(csv).sublist(1, 4), [
        '2026-11-05,08:03,ミケ,ご飯,少し,,,,完食,はる,あり',
        '2026-11-06,21:00,ミケ,体重,,4.2,,,,はる,',
        '2026-11-05,08:03,ミケ,病院,,,みどり動物病院,2026-12-01,,はる,',
      ]);
    });

    test('体重でない項目の数値・病院でない項目の詳細は出さない。知らない量は空', () {
      final csv = buildRecordCsv([
        entry('r1', weight: 9, detail: '{"hospital": "x"}', level: 'huge'),
      ], all);
      expect(lines(csv)[1], '2026-11-05,08:03,ミケ,ご飯,,,,,,はる,');
    });
  });

  group('UT-EX-02 絞り込み', () {
    final records = [
      entry('r1'),
      entry('r2', catId: 'c2', catName: 'タマ'),
      entry('r3', typeId: 't2', typeName: '水'),
    ];

    int count(CsvFilter f) => lines(buildRecordCsv(records, f)).length - 2;

    test('猫・項目が「すべて」なら全部、選べば選んだものだけ。組み合わせられる', () {
      expect(count(all), 3);
      expect(
        count((from: null, to: null, catIds: {'c1'}, recordTypeIds: null)),
        2,
      );
      expect(
        count((from: null, to: null, catIds: null, recordTypeIds: {'t2'})),
        1,
      );
      expect(
        count((from: null, to: null, catIds: {'c2'}, recordTypeIds: {'t2'})),
        0,
      );
    });

    test('境界値：期間は開始日の0時から、終了日を含む次の日の0時まで。全期間は明日の0時まで', () {
      final now = DateTime(2026, 11, 25, 10);
      final r = csvRange((
        from: DateTime(2026, 11, 1, 15),
        to: DateTime(2026, 11, 3, 9),
        catIds: null,
        recordTypeIds: null,
      ), now);
      expect(r.from, DateTime(2026, 11, 1));
      expect(r.to, DateTime(2026, 11, 4));
      // 月末の次は翌月の1日
      expect(
        csvRange((
          from: DateTime(2026, 11, 30),
          to: DateTime(2026, 11, 30),
          catIds: null,
          recordTypeIds: null,
        ), now).to,
        DateTime(2026, 12, 1),
      );
      final whole = csvRange(all, now);
      expect(whole.from, DateTime(2000));
      expect(whole.to, DateTime(2026, 11, 26));
    });
  });

  group('UT-EX-03 1つの欄（RFC 4180・CSV インジェクション）', () {
    test('カンマ・引用符・改行を含むと引用符で囲み、中の引用符は2つにする', () {
      expect(csvCell('ふつう'), 'ふつう');
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('「"大好き"」'), '"「""大好き""」"');
      expect(csvCell('1行目\n2行目'), '"1行目\n2行目"');
      expect(csvCell(''), '');
    });

    test('= + - @ で始まる文字は、式として動かないよう先頭に \' を付ける', () {
      expect(csvCell('=1+1'), "'=1+1");
      expect(csvCell('+81'), "'+81");
      expect(csvCell('-'), "'-");
      expect(csvCell('@a'), "'@a");
      // 途中にあるだけなら付けない
      expect(csvCell('a=b'), 'a=b');
      // 付けた後も、カンマがあれば囲む
      expect(csvCell('=a,b'), '"\'=a,b"');
    });

    test('ファイルの名前の案は日付入り', () {
      expect(
        suggestedCsvName(DateTime(2026, 1, 5, 9)),
        'meowscope_20260105.csv',
      );
    });
  });
}
