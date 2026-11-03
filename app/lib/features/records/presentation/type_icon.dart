import 'package:flutter/material.dart';

import '../domain/custom_type.dart';
import '../domain/record_kind.dart';

/// 独自の項目の仮のアイコン。イラストが届いたら差し替える
IconData customIconData(CustomIcon icon) => switch (icon) {
  CustomIcon.hospital => Icons.local_hospital_outlined,
  CustomIcon.toy => Icons.toys_outlined,
  CustomIcon.nail => Icons.content_cut,
  CustomIcon.bath => Icons.bathtub_outlined,
  CustomIcon.star => Icons.star_outline,
};

/// 記録項目のアイコン。イラストがあればイラスト、なければ仮のアイコン
class TypeIcon extends StatelessWidget {
  const TypeIcon({super.key, required this.icon, required this.name});

  /// record_types.icon の値
  final String? icon;

  /// 読み上げに使う項目の名前
  final String name;

  @override
  Widget build(BuildContext context) {
    final asset = iconAsset(icon);
    if (asset != null) {
      return Image.asset(asset, semanticLabel: name);
    }
    return Icon(
      customIconData(CustomIcon.parse(icon) ?? CustomIcon.star),
      semanticLabel: name,
    );
  }
}
