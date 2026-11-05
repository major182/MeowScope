import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../icons/icon_avatar.dart';
import '../../icons/icon_repository.dart';

/// 絞り込みに出す猫（お別れを含み、削除済みを除く）
final filterCatsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchCats(session.householdId);
});

/// 全員または1匹を選ぶ（カレンダー・統計の画面上部）。
/// allowAll が false なら「全員」を出さない（統計は1匹の表示が基本）
class CatFilter extends ConsumerWidget {
  const CatFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowAll = true,
  });

  /// 選んでいる猫の ID。null は全員
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(filterCatsProvider).value ?? const [];
    // 選んでいた猫が消えたときは全員（または先頭）に戻す
    final value = cats.any((c) => c.id == selected) ? selected : null;
    return DropdownButton<String?>(
      value: value,
      hint: const Text('猫を選ぶ'),
      onChanged: onChanged,
      items: [
        if (allowAll)
          const DropdownMenuItem<String?>(value: null, child: Text('全員')),
        for (final c in cats)
          DropdownMenuItem<String?>(
            value: c.id,
            child: IconLabel(
              icon: IconRef(
                IconOwner.cat,
                c.id,
                hasIcon: c.hasIcon,
                version: c.serverSeq,
              ),
              text: c.status == 'farewell' ? '${c.name}（お別れ）' : c.name,
            ),
          ),
      ],
    );
  }
}
