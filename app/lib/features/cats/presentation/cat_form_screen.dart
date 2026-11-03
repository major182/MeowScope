import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../household/data/household_repository.dart';
import '../data/cat_repository.dart';

/// 猫1匹を見張る
final catProvider = StreamProvider.autoDispose.family<CatRow?, String>(
  (ref, id) => ref.watch(catRepositoryProvider).watchCat(id),
);

/// 猫のプロフィール（S-41）。猫を読み込んでから編集の画面を出す
class CatProfileScreen extends ConsumerWidget {
  const CatProfileScreen({super.key, required this.catId, this.today});

  final String catId;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(catProvider(catId))
        .when(
          data: (cat) => cat == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: Text('この猫は見つかりません')),
                )
              : CatFormScreen(key: ValueKey(catId), initial: cat, today: today),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('この猫は見つかりません')),
          ),
        );
  }
}

/// 猫の登録（S-05）とプロフィールの編集（S-41）。名前以外は任意（BR-24）。
/// 写真はアイコンの実装で足す
class CatFormScreen extends ConsumerStatefulWidget {
  const CatFormScreen({super.key, this.today, this.initial});

  /// 生年月日に選べる最後の日。テストで日付を固定するために渡す
  final DateTime? today;

  /// 編集する猫。null なら新しく登録する
  final CatRow? initial;

  @override
  ConsumerState<CatFormScreen> createState() => _CatFormScreenState();
}

class _CatFormScreenState extends ConsumerState<CatFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _conditions = TextEditingController(
    text: widget.initial?.conditions,
  );
  // 生年月日は UTC の年月日で保存しているので、その年月日で戻す
  late DateTime? _birthDate = switch (widget.initial?.birthDate?.toUtc()) {
    final b? => DateTime(b.year, b.month, b.day),
    null => null,
  };
  late CatSex? _sex = CatSex.values
      .where((s) => s.name == widget.initial?.sex)
      .firstOrNull;
  var _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = widget.today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? today,
      firstDate: DateTime(today.year - 40),
      // 未来の日付は選べない
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save(Session session) async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final repo = ref.read(catRepositoryProvider);
    final initial = widget.initial;
    if (initial != null) {
      await repo.updateCat(
        id: initial.id,
        userId: session.author.id,
        name: name,
        birthDate: _birthDate,
        sex: _sex,
        conditions: _conditions.text,
      );
      messenger.showSnackBar(SnackBar(content: Text('$nameを保存しました')));
      router.pop();
      return;
    }
    await repo.addCat(
      householdId: session.householdId,
      userId: session.author.id,
      name: name,
      birthDate: _birthDate,
      sex: _sex,
      conditions: _conditions.text,
    );
    messenger.showSnackBar(SnackBar(content: Text('$nameを登録しました')));
    // 一覧などから開いたときは戻り、最初の登録のときはホームへ進む
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }

  Future<void> _toggleFarewell(Session session, CatRow cat) async {
    final farewell = cat.status != 'farewell';
    await ref
        .read(catRepositoryProvider)
        .setFarewell(id: cat.id, userId: session.author.id, farewell: farewell);
  }

  Future<void> _delete(Session session, CatRow cat) async {
    final router = GoRouter.of(context);
    final ok = await confirmDelete(
      context,
      title: '${cat.name}を削除しますか？',
      message: '${cat.name}の記録もすべて消えます。記録を残すときは「お別れにする」を使ってください',
    );
    if (!ok) {
      return;
    }
    await ref
        .read(catRepositoryProvider)
        .deleteCat(id: cat.id, userId: session.author.id);
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    // 画面を開いた時点でセッションを読み込み、読み込むまでは登録できなくする
    final session = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '${widget.initial!.name}のプロフィール' : '猫を登録しましょう'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '名前'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? '名前を入力してください' : null,
            ),
            const SizedBox(height: 16),
            Text('以下は任意です', style: Theme.of(context).textTheme.bodySmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('生年月日'),
              subtitle: Text(
                birth == null
                    ? '未設定'
                    : '${birth.year}/${birth.month}/${birth.day}',
              ),
              trailing: Wrap(
                children: [
                  if (birth != null)
                    IconButton(
                      tooltip: '生年月日を消す',
                      onPressed: () => setState(() => _birthDate = null),
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    tooltip: '生年月日を選ぶ',
                    onPressed: _pickBirthDate,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ],
              ),
            ),
            const Text('性別'),
            const SizedBox(height: 4),
            SegmentedButton<CatSex>(
              segments: [
                for (final s in CatSex.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {?_sex},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _sex = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _conditions,
              decoration: const InputDecoration(labelText: '持病'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || session == null
                  ? null
                  : () => _save(session),
              child: Text(_editing ? '保存する' : '登録する'),
            ),
            if (widget.initial case final cat? when session != null) ...[
              const Divider(height: 48),
              // CatProfileScreen が猫を見張っているので、cat は最新の状態
              OutlinedButton(
                onPressed: () => _toggleFarewell(session, cat),
                child: Text(cat.status == 'farewell' ? 'お別れを取り消す' : 'お別れにする'),
              ),
              if (cat.status == 'farewell')
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('お別れの猫は記録の対象から外れます。記録は残ります'),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _delete(session, cat),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('削除する'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
