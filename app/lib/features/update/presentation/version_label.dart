import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../update_providers.dart';

/// 今の版の文（例：Ver.1.0.0）。ビルド番号は出さない（F-UP-03、画面設計書 S-01）
///
/// 読めないとき・読んでいる間は空にする（版が出ないだけで、ほかの操作は妨げない）
String versionText(WidgetRef ref) {
  final installed = ref.watch(installedVersionProvider).value;
  return installed == null ? '' : 'Ver.${installed.version}';
}

/// 画面の下に出す今の版（S-01）
class VersionLabel extends ConsumerWidget {
  const VersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        versionText(ref),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
