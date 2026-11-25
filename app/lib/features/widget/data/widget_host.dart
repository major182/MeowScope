import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// ウィジェットとのやりとりのキー。Android の側（RecordWidgetProvider.kt）と合わせる
abstract final class WidgetKeys {
  /// 描く内容（WidgetSnapshot の JSON）
  static const snapshot = 'meowscope.snapshot';

  /// 今の表示（ボタン・猫の選択・記録中・記録の結果）。ウィジェットごとに持つ（BR-40）
  static String ui(int widgetId) => 'meowscope.ui.$widgetId';

  /// 記録待ちの印（押した時刻）。Android の側が付け、保存を終えたらこちらで消す。ウィジェットごとに持つ
  static String pending(int widgetId) => 'meowscope.pending.$widgetId';
}

/// 失敗の文を出す時間。過ぎたら元のボタンに戻す（Android の側と同じ）
const failedDuration = Duration(seconds: 3);

/// ウィジェットへデータを渡す口。テストでは差し替える
abstract class WidgetHost {
  Future<void> save(String key, String value);

  /// 値を消す
  Future<void> remove(String key);

  /// ウィジェットを描き直す
  Future<void> refresh();

  /// [widgetId] のウィジェットの表示を切り替える。[until] を過ぎたら、Android の側で元のボタンに戻す
  Future<void> showUi(
    int widgetId,
    String mode, {
    String? message,
    DateTime? until,
  }) async {
    await save(
      WidgetKeys.ui(widgetId),
      jsonEncode({
        'mode': mode,
        'message': ?message,
        if (until != null) 'until': until.millisecondsSinceEpoch,
      }),
    );
    await refresh();
  }
}

/// home_widget を使う本物の口（Android）
class HomeWidgetHost extends WidgetHost {
  static const _provider = 'com.meowscope.meowscope.RecordWidgetProvider';

  @override
  Future<void> save(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> remove(String key) =>
      HomeWidget.saveWidgetData<String>(key, null);

  @override
  Future<void> refresh() =>
      HomeWidget.updateWidget(qualifiedAndroidName: _provider);
}
