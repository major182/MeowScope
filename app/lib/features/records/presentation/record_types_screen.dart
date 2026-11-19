import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../domain/custom_type.dart';
import '../domain/record_kind.dart';
import '../domain/type_order.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import 'record_providers.dart';
import 'type_icon.dart';

/// 記録項目の設定（S-43）。標準の項目は変えられず、独自の項目は編集と非表示ができる。
/// 削除はできない
class RecordTypesScreen extends ConsumerWidget {
  const RecordTypesScreen({super.key});

  Future<void> _setHidden(WidgetRef ref, RecordTypeRow type) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    await ref
        .read(recordRepositoryProvider)
        .setTypeHidden(
          id: type.id,
          userId: session.author.id,
          hidden: !type.hidden,
        );
  }

  /// 並べ替えを、この端末の並び順として保存する（F-RC-07、BR-36）。
  /// 非表示の項目も含めた全体の順を残す（表示に戻したときの位置になる）
  Future<void> _reorder(
    WidgetRef ref,
    List<RecordTypeRow> types,
    int oldIndex,
    int newIndex,
  ) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    await ref
        .read(settingsRepositoryProvider)
        .setTypeOrder(
          session.householdId,
          moveTypeOrder([for (final t in types) t.id], oldIndex, newIndex),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 非表示にするときにセッションを使うので、読み込んでおく
    ref.watch(sessionProvider);
    final types = ref.watch(orderedAllRecordTypesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録項目'),
        actions: [
          TextButton(
            onPressed: () => context.push('/record-types/new'),
            child: const Text('追加'),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: readablePadding(context, 0),
        // つまみ（≡）を押して動かす。一覧のどこでも長押しで動くと、
        // 「編集」などのボタンやスクロールと取り違えやすいため
        buildDefaultDragHandles: false,
        onReorderItem: (oldIndex, newIndex) =>
            _reorder(ref, types, oldIndex, newIndex),
        children: [
          for (final (i, t) in types.indexed)
            ListTile(
              key: ValueKey(t.id),
              leading: SizedBox(
                width: 40,
                child: TypeIcon(
                  icon: typeIconValue(t.kind, t.icon),
                  name: t.name,
                ),
              ),
              title: Text(
                t.kind == RecordKind.custom ? t.name : '${t.name}（標準）',
              ),
              subtitle: t.hidden ? const Text('非表示中') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.kind == RecordKind.custom) ...[
                    TextButton(
                      onPressed: () => context.push('/record-types/${t.id}'),
                      child: const Text('編集'),
                    ),
                    TextButton(
                      onPressed: () => _setHidden(ref, t),
                      child: Text(t.hidden ? '表示に戻す' : '非表示にする'),
                    ),
                  ],
                  // すぐにつかめるつまみ（マウスでも指でも動かせる）
                  ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: '${t.name}を動かす',
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 独自の項目の追加と編集。typeId が null なら追加
class RecordTypeFormScreen extends ConsumerStatefulWidget {
  const RecordTypeFormScreen({super.key, this.typeId});

  final String? typeId;

  @override
  ConsumerState<RecordTypeFormScreen> createState() =>
      _RecordTypeFormScreenState();
}

class _RecordTypeFormScreenState extends ConsumerState<RecordTypeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  var _icon = CustomIcon.selectable.first;
  var _loaded = false;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 編集のとき、読み込んだ項目を入力欄に入れる（1回だけ）
  RecordTypeRow? _editing(List<RecordTypeRow> types) {
    final type = types
        .where((t) => t.id == widget.typeId && t.kind == RecordKind.custom)
        .firstOrNull;
    if (type != null && !_loaded) {
      _loaded = true;
      _name.text = type.name;
      _icon = CustomIcon.parse(type.icon) ?? CustomIcon.selectable.first;
    }
    return type;
  }

  Future<void> _save(List<RecordTypeRow> types) async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final repo = ref.read(recordRepositoryProvider);
    final id = widget.typeId;
    final saved = await guardSave(
      log: ref.read(appLogProvider),
      messenger: ScaffoldMessenger.of(context),
      what: '記録項目の保存',
      action: () async {
        if (id == null) {
          await repo.addCustomType(
            householdId: session.householdId,
            userId: session.author.id,
            name: _name.text,
            icon: _icon.value,
          );
        } else {
          await repo.updateCustomType(
            id: id,
            userId: session.author.id,
            name: _name.text,
            icon: _icon.value,
          );
        }
      },
    );
    if (!saved) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    // 保存のときにセッションを使うので、読み込んでおく
    ref.watch(sessionProvider);
    // 名前の重なりは非表示の項目も含めて確かめる
    final types = ref.watch(allRecordTypesProvider).value;
    if (types == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final editing = _editing(types);
    if (widget.typeId != null && editing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('この項目は見つかりません')),
      );
    }
    final others = [
      for (final t in types)
        if (t.id != widget.typeId) t.name,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? '項目を追加' : '項目を編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(types),
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: readablePadding(context, 16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '名前'),
              maxLength: maxTypeNameLength,
              validator: (v) => validateTypeName(v, others),
            ),
            const SizedBox(height: 16),
            const Text('アイコン'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 選べるアイコン。まとめる前に作った通院の項目を編集するときだけ、今のアイコンも残す
                for (final i in CustomIcon.values)
                  if (CustomIcon.selectable.contains(i) || i == _icon)
                    ChoiceChip(
                      avatar: Image.asset('assets/icons/${i.value}.png'),
                      label: Text(i.label),
                      selected: _icon == i,
                      onSelected: (_) => setState(() => _icon = i),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
