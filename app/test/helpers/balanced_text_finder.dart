import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/widgets/balanced_text.dart';

/// [BalancedText] を元の文で探す（画面の文字には改行させない印が入るので、find.text では見つからない）
Finder findBalancedText(String text) => find.byWidgetPredicate(
  (w) => w is BalancedText && w.data == text,
  description: 'BalancedText「$text」',
);
