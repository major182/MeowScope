import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/balanced_text.dart';
import '../../icons/icon_avatar.dart';
import '../../icons/icon_repository.dart';

/// 記録の対象にできる猫（お別れを除く、登録の順）。ホームと日付からの記録で使う
final activeCatsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

/// 猫の選択（S-11）。猫が1匹なら選択を省いてその猫を返す（BR-23 と同じ考え）。
/// 選ばずに閉じたら null
Future<CatRow?> pickCat(
  BuildContext context,
  List<CatRow> cats,
  String typeName,
) async {
  if (cats.length == 1) {
    return cats.single;
  }
  return showDialog<CatRow>(
    context: context,
    builder: (context) => SimpleDialog(
      title: BalancedText('$typeName：どの子ですか？'),
      children: [
        for (final c in cats)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, c),
            child: IconLabel(
              icon: IconRef(
                IconOwner.cat,
                c.id,
                hasIcon: c.hasIcon,
                version: c.serverSeq,
              ),
              text: c.name,
              radius: 16,
            ),
          ),
        // 外側を押しても閉じるが、閉じ方が分かるようにボタンも置く（S-11）
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ),
        ),
      ],
    ),
  );
}
