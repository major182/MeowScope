import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../../records/presentation/record_providers.dart';
import '../../records/presentation/type_icon.dart';
import '../data/widget_button_repository.dart';

/// 今のおうちの、自分のウィジェットのボタン
final widgetButtonsProvider =
    StreamProvider.autoDispose<List<WidgetButtonView>>((ref) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(widgetButtonRepositoryProvider)
          .watchButtons(session.author.id, session.householdId);
    });

/// ウィジェットのボタン設定（S-44）。追加・削除・並べ替えができる
class WidgetButtonsScreen extends ConsumerWidget {
  const WidgetButtonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final buttons = ref.watch(widgetButtonsProvider).value ?? const [];
    final types = ref.watch(recordTypesProvider).value ?? const [];
    final repo = ref.read(widgetButtonRepositoryProvider);
    final full = buttons.length >= WidgetButtonRepository.maxButtons;
    final added = {for (final b in buttons) b.type.id};
    final choices = [
      for (final t in types)
        if (!added.contains(t.id)) t,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('ウィジェットのボタン')),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readablePadding(context, 12),
              children: [
                if (buttons.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('ボタンがありません'),
                  ),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) {
                    final ids = [for (final b in buttons) b.id];
                    ids.insert(to, ids.removeAt(from));
                    repo.reorder(userId: session.author.id, orderedIds: ids);
                  },
                  children: [
                    for (final (i, b) in buttons.indexed)
                      Card(
                        key: ValueKey(b.id),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: TypeIcon(
                                  icon: b.type.icon,
                                  name: b.type.name,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(child: Text(b.type.name)),
                            ],
                          ),
                          subtitle: b.type.hidden ? const Text('非表示中') : null,
                          trailing: TextButton(
                            onPressed: () => repo.remove(
                              userId: session.author.id,
                              id: b.id,
                            ),
                            child: const Text('削除'),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: full || choices.isEmpty
                      ? null
                      : () async {
                          final type = await _choose(context, choices);
                          if (type != null) {
                            await repo.add(
                              userId: session.author.id,
                              recordTypeId: type.id,
                            );
                          }
                        },
                  child: const Text('ボタンを追加'),
                ),
                if (full)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'ボタンは${WidgetButtonRepository.maxButtons}つまでです',
                    ),
                  ),
              ],
            ),
    );
  }

  /// 追加する記録項目を選ぶ。閉じたら null
  Future<RecordTypeRow?> _choose(
    BuildContext context,
    List<RecordTypeRow> choices,
  ) => showDialog<RecordTypeRow>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('ボタンにする項目'),
      children: [
        for (final t in choices)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, t),
            child: Text(t.name),
          ),
      ],
    ),
  );
}
