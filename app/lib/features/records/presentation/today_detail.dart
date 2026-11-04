import 'package:flutter/foundation.dart';

import '../data/record_repository.dart';
import '../domain/record_detail.dart';
import 'record_format.dart';

/// 今日の記録に出す詳細の量。Windows は写真以外のすべて、Android は量とメモ
enum TodayDetail {
  all,
  levelAndMemo;

  /// 動いている端末に合わせて選ぶ
  static TodayDetail get forPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ? all : levelAndMemo;
}

/// 今日の記録の2行目に出す詳細。出すものがなければ null
///
/// 項目ごとに「量：多い」のように見出しを付け、全角の空白でつなぐ
String? todayDetailText(RecordEntry e, TodayDetail detail) {
  final level = RecordLevel.parse(e.level);
  final parts = [
    if (level != null) '量：${level.label}',
    if (detail == TodayDetail.all && e.valueNumber != null)
      '体重：${formatWeight(e.valueNumber!)}',
    if (e.memo != null) 'メモ：${e.memo}',
    if (detail == TodayDetail.all && e.authorName.isNotEmpty)
      '投稿者：${e.authorName}',
  ];
  return parts.isEmpty ? null : parts.join('　');
}
