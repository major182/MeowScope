import 'package:flutter/material.dart';

import '../domain/record_kind.dart';

/// 記録項目のイラスト。イラストが見つからなければ「その他」のイラストを出す
class TypeIcon extends StatelessWidget {
  const TypeIcon({super.key, required this.icon, required this.name});

  /// record_types.icon の値
  final String? icon;

  /// 読み上げに使う項目の名前
  final String name;

  @override
  Widget build(BuildContext context) =>
      Image.asset(iconAsset(icon) ?? fallbackIconAsset, semanticLabel: name);
}
