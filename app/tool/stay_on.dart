/// Android の「画面を消さない（充電中にスリープしない）」の設定（#316）
///
/// `adb shell settings get global stay_on_while_plugged_in` の出力を読む。
/// 0 はオフ、1〜15 はどの充電（AC・USB・ワイヤレスなど）のときにオンかを表す数。
/// E2E の後に、始める前の値へ戻すために使う
library;

/// コマンドの結果から設定の値を読む。失敗したときと、数でないとき（`null` など）は null（戻さない）
String? parseStayOn(int exitCode, String stdout) {
  final value = stdout.trim();
  return exitCode == 0 && RegExp(r'^\d+$').hasMatch(value) ? value : null;
}
