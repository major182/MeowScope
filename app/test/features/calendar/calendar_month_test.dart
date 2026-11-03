import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/calendar/domain/calendar_month.dart';
import 'package:meowscope/features/calendar/presentation/calendar_screen.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';

RecordEntry _entry(DateTime at, String kind, {bool memo = false}) =>
    RecordEntry(
      id: '$at$kind',
      recordedAt: at,
      catName: 'ミケ',
      typeName: kind == 'custom' ? '通院' : kind,
      catId: 'c1',
      kind: kind,
      hasMemo: memo,
      recordTypeId: kind,
      typeIcon: kind == 'custom' ? 'custom_vet' : null,
    );

String _cal(String name) => 'assets/icons/cal_$name.png';

void main() {
  test('UT-CL-01 週の始まりの値：monday／sunday／空／知らない値（同値分割）', () {
    expect(WeekStart.parse('monday'), WeekStart.monday);
    expect(WeekStart.parse('sunday'), WeekStart.sunday);
    expect(WeekStart.parse(null), WeekStart.sunday);
    expect(WeekStart.parse('friday'), WeekStart.sunday);
  });

  test('UT-CL-02 曜日の見出しは週の始まりから並ぶ', () {
    expect(WeekStart.sunday.labels.first, '日');
    expect(WeekStart.sunday.labels.last, '土');
    expect(WeekStart.monday.labels.first, '月');
    expect(WeekStart.monday.labels.last, '日');
  });

  group('monthGrid', () {
    test('UT-CL-03 6行7列（42日）で、1日ずつ続く', () {
      final days = monthGrid(DateTime(2026, 2), WeekStart.sunday);

      expect(days, hasLength(42));
      for (var i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inHours, 24);
      }
    });

    test('UT-CL-04 境界値：日曜に始まる月（2026年11月）', () {
      final sunday = monthGrid(DateTime(2026, 11), WeekStart.sunday);
      final monday = monthGrid(DateTime(2026, 11), WeekStart.monday);

      expect(sunday.first, DateTime(2026, 11, 1));
      expect(monday.first, DateTime(2026, 10, 26));
    });

    test('UT-CL-05 境界値：月曜に始まる月（2026年6月）', () {
      final sunday = monthGrid(DateTime(2026, 6), WeekStart.sunday);
      final monday = monthGrid(DateTime(2026, 6), WeekStart.monday);

      expect(sunday.first, DateTime(2026, 5, 31));
      expect(monday.first, DateTime(2026, 6, 1));
      expect(monday.last, DateTime(2026, 7, 12));
    });

    test('UT-CL-06 月の途中の日を渡しても、その月の表になる', () {
      expect(
        monthGrid(DateTime(2026, 11, 20), WeekStart.sunday).first,
        DateTime(2026, 11, 1),
      );
    });
  });

  test('UT-CL-07 印のイラスト：標準の8項目はカレンダー用／独自の項目は選んだイラスト／見つからなければ「その他」', () {
    expect(
      [for (final k in RecordKind.values) calendarAsset(k.name, k.icon)],
      [
        for (final n in [
          'food',
          'water',
          'medicine',
          'pee',
          'poop',
          'vomit',
          'weight',
          'brushing',
        ])
          _cal(n),
      ],
    );
    expect(
      calendarAsset('custom', 'custom_vet'),
      'assets/icons/custom_vet.png',
    );
    expect(calendarAsset('custom', 'custom_hospital'), fallbackIconAsset);
    expect(calendarAsset('custom', null), fallbackIconAsset);
  });

  test('UT-CL-08 印の並び：標準の順で、独自の項目は後ろ', () {
    expect(kindOrder('food'), 0);
    expect(kindOrder('brushing'), 7);
    expect(kindOrder('custom'), 8);
  });

  test('UT-CL-09 日ごとの印：標準の順に1つずつ、メモがあれば最後にメモの印', () {
    final day = DateTime(2026, 11, 2);
    final marks = dayMarks([
      _entry(day.add(const Duration(hours: 9)), 'stool'),
      _entry(day.add(const Duration(hours: 8)), 'custom'),
      _entry(day.add(const Duration(hours: 7)), 'food'),
      _entry(day.add(const Duration(hours: 12)), 'food', memo: true),
      _entry(DateTime(2026, 11, 3, 1), 'water'),
    ]);

    expect(marks[day]!.map((m) => m.asset), [
      _cal('food'),
      _cal('poop'),
      'assets/icons/custom_vet.png',
      memoAsset,
    ]);
    expect(marks[day]!.map((m) => m.label), ['food', 'stool', '通院', 'メモあり']);
    expect(marks[DateTime(2026, 11, 3)]!.map((m) => m.asset), [_cal('water')]);
    expect(marks[DateTime(2026, 11, 4)], isNull);
  });

  test('UT-CL-10 同じ日か・日付だけにする', () {
    expect(
      isSameDay(DateTime(2026, 11, 2, 0), DateTime(2026, 11, 2, 23)),
      isTrue,
    );
    expect(isSameDay(DateTime(2026, 11, 2), DateTime(2026, 12, 2)), isFalse);
    expect(dateOnly(DateTime(2026, 11, 2, 9, 30)), DateTime(2026, 11, 2));
  });
}
