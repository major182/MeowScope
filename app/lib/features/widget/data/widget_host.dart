import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// ウィジェットとのやりとりのキー。Android の側（RecordWidgetProvider.kt）と合わせる
abstract final class WidgetKeys {
  /// 描く内容（WidgetSnapshot の JSON）
  static const snapshot = 'meowscope.snapshot';

  /// 今の表示（ボタン・猫の選択・記録中・記録の結果）
  static const ui = 'meowscope.ui';
}

/// 記録の結果を出す時間。過ぎたら元のボタンに戻す
const doneDuration = Duration(seconds: 2);

/// ウィジェットへデータを渡す口。テストでは差し替える
abstract class WidgetHost {
  Future<void> save(String key, String value);

  /// ウィジェットを描き直す
  Future<void> refresh();

  /// 表示を切り替える。[until] を過ぎたら、Android の側で元のボタンに戻す
  Future<void> showUi(String mode, {String? message, DateTime? until}) async {
    await save(
      WidgetKeys.ui,
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
  Future<void> refresh() =>
      HomeWidget.updateWidget(qualifiedAndroidName: _provider);
}
