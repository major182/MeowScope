/// 送れなかった変更の原因と対応の案内（S-48、Issue #83）
///
/// サーバーの理由（API 設計書 5章）ごとに、利用者に分かる言葉で「なぜ」と「どうすればよいか」を決める
class RejectedGuidance {
  const RejectedGuidance({
    required this.cause,
    required this.action,
    required this.canResend,
  });

  /// なぜ送れなかったか
  final String cause;

  /// どうすればよいか
  final String action;

  /// 「送り直す」を出すか。送り直しても結果が変わらない理由（権限）では出さない
  final bool canResend;
}

/// 項目の名前（サーバーの field）を、画面の言葉にする。知らない名前はそのまま出す
String fieldLabel(String field) => switch (field) {
  'level' => '量',
  'valueNumber' => '体重',
  'memo' => 'メモ',
  'detail' => '詳細',
  'recordedAt' => '日時',
  'authorName' => '投稿者の名前',
  'name' => '名前',
  'birthDate' => '生年月日',
  'sex' => '性別',
  'conditions' => '持病',
  'status' => '状態',
  'icon' => 'アイコン',
  'kind' => '種類',
  'hidden' => '非表示',
  'sortOrder' => '並び順',
  'weekStart' => '週の始まり',
  'catId' => '猫',
  'recordTypeId' => '記録項目',
  'recordId' => '記録',
  'householdId' => 'おうち',
  _ => field,
};

/// 理由ごとの案内
RejectedGuidance guidanceFor(String reason, String? field) => switch (reason) {
  'unknown_table' => const RejectedGuidance(
    cause: 'サーバーが、この種類のデータにまだ対応していません（アプリとサーバーの版の違い）',
    action: 'サーバーが新しくなった後に「送り直す」を押してください。送れないままなら、問い合わせてください',
    canResend: true,
  ),
  'forbidden' => const RejectedGuidance(
    cause: 'このおうちに変更を送る権限がありません（別の端末でおうちを抜けた後の変更など）',
    action: 'この変更はサーバーに送れません。内容を確かめたら「一覧から消す」を押してください',
    canResend: false,
  ),
  'not_found' || 'constraint' => const RejectedGuidance(
    cause: 'もとになる猫・記録項目・記録が、サーバーにありません（別の端末で削除されたなど）',
    action: 'もとのデータがあるか確かめてください。なければ記録し直して、この変更は「一覧から消す」を押してください',
    canResend: true,
  ),
  'invalid' => RejectedGuidance(
    cause: field == null
        ? '内容が決まりに合いません'
        : '「${fieldLabel(field)}」の内容が決まりに合いません',
    action: field == null
        ? '内容を直してから「送り直す」を押してください'
        : '「${fieldLabel(field)}」を直してから「送り直す」を押してください',
    canResend: true,
  ),
  'too_many' => const RejectedGuidance(
    cause: '数の上限を超えています（写真は1つの記録に3枚、ウィジェットのボタンは4つまで）',
    action: '数を減らしてから「送り直す」を押してください',
    canResend: true,
  ),
  _ => const RejectedGuidance(
    cause: 'サーバーが受け付けませんでした',
    action: '「送り直す」で送れないときは、問い合わせてください',
    canResend: true,
  ),
};
