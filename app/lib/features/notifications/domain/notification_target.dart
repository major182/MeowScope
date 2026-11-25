/// 通知を押したときに開く場所（payload）と、どのおうちの通知か（BR-39）
///
/// おうちが2つ以上あると、今のおうちとは別のおうちの通知も出る。押したときにそのおうちへ
/// 切り替えてから開けるよう、開く場所の問い合わせ（`?` の後ろ）に `household` を添える
library;

/// 問い合わせの名前。画面の側の問い合わせ（`cat` など）とぶつからない名前にする
const householdQuery = 'household';

/// [path] に、どのおうちの通知かを添える。[householdId] が null なら、そのまま返す
String withHousehold(String path, String? householdId) {
  if (householdId == null) {
    return path;
  }
  final uri = Uri.parse(path);
  return Uri(
    path: uri.path,
    queryParameters: {...uri.queryParameters, householdQuery: householdId},
  ).toString();
}

/// 添えたおうちと、それを外した開く場所に分ける
({String? householdId, String path}) splitHousehold(String payload) {
  final uri = Uri.parse(payload);
  final householdId = uri.queryParameters[householdQuery];
  if (householdId == null) {
    return (householdId: null, path: payload);
  }
  final rest = {...uri.queryParameters}..remove(householdQuery);
  return (
    householdId: householdId,
    path: Uri(
      path: uri.path,
      queryParameters: rest.isEmpty ? null : rest,
    ).toString(),
  );
}
