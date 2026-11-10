import '../data/notifier.dart';
import 'reminder_plan.dart' show notificationId;

/// 家族の記録の通知に使う記録（同期で受け取った、自分以外の人の新しい記録）
class FamilyRecord {
  const FamilyRecord({
    required this.id,
    required this.authorKey,
    required this.authorName,
    required this.catName,
    required this.typeName,
    required this.catId,
    required this.recordedAt,
  });

  final String id;

  /// 記録した人を見分けるもの（ユーザーの ID。退会した人は表示名）
  final String authorKey;
  final String authorName;
  final String catName;
  final String typeName;
  final String catId;

  /// 記録の日時（端末の時刻）
  final DateTime recordedAt;
}

/// 家族の記録の通知を押したときに開く場所：最初の記録の日の日別一覧（S-21）。
/// まとめた記録がすべて同じ猫なら、その猫で絞る
String familyPayload(List<FamilyRecord> group) {
  final d = group.first.recordedAt;
  final date =
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final cats = {for (final r in group) r.catId};
  return Uri(
    path: '/days/$date',
    queryParameters: cats.length == 1 ? {'cat': cats.single} : null,
  ).toString();
}

/// 家族の記録の通知（画面設計書 4章、F-NT-04、BR-08）
///
/// 記録した人ごとに1つにまとめる。1件なら「なつさんがミケのご飯を記録しました」、
/// 何件もあれば「なつさんが3件記録しました」。通知の文に、メモや記録の詳細は入れない
List<AppNotification> familyNotifications(List<FamilyRecord> records) {
  final byAuthor = <String, List<FamilyRecord>>{};
  for (final r in records) {
    byAuthor.putIfAbsent(r.authorKey, () => []).add(r);
  }
  return [
    for (final group in byAuthor.values)
      AppNotification(
        // 同じ人の前の通知を置き換えないよう、最初の記録の ID から作る
        id: notificationId('family', group.first.id),
        title: group.length == 1
            ? '${group.first.authorName}さんが${group.first.catName}の${group.first.typeName}を記録しました'
            : '${group.first.authorName}さんが${group.length}件記録しました',
        payload: familyPayload(group),
      ),
  ];
}
