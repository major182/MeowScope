import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/presentation/today_detail.dart';

RecordEntry _entry({
  String? level,
  double? kg,
  String? memo,
  String author = 'はる',
}) => RecordEntry(
  id: 'r1',
  recordedAt: DateTime(2026, 11, 4, 8),
  catName: 'ミケ',
  typeName: 'ご飯',
  catId: 'c1',
  kind: 'food',
  hasMemo: memo != null,
  recordTypeId: 't1',
  valueNumber: kg,
  level: level,
  memo: memo,
  authorName: author,
);

void main() {
  test('UT-TD-01 Windows（all）：量・体重・メモ・投稿者を、見出し付きで全角の空白でつなぐ', () {
    expect(
      todayDetailText(
        _entry(level: 'much', kg: 4.2, memo: '完食'),
        TodayDetail.all,
      ),
      '量：多い　体重：4.2 kg　メモ：完食　投稿者：はる',
    );
  });

  test('UT-TD-02 Android（levelAndMemo）：量とメモだけ。体重と投稿者は出さない', () {
    final e = _entry(level: 'little', kg: 4.2, memo: '残した');
    expect(todayDetailText(e, TodayDetail.levelAndMemo), '量：少し　メモ：残した');
    expect(todayDetailText(_entry(kg: 4.2), TodayDetail.levelAndMemo), isNull);
  });

  test('UT-TD-03 出すものがなければ null（量が知らない値・投稿者が空のときも含む）', () {
    expect(
      todayDetailText(_entry(level: 'unknown', author: ''), TodayDetail.all),
      isNull,
    );
    expect(todayDetailText(_entry(), TodayDetail.levelAndMemo), isNull);
  });

  test('UT-TD-04 端末に合わせて選ぶ：Windows は all、Android は levelAndMemo', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(TodayDetail.forPlatform, TodayDetail.all);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(TodayDetail.forPlatform, TodayDetail.levelAndMemo);
    debugDefaultTargetPlatformOverride = null;
  });
}
