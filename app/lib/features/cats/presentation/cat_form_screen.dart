import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../household/data/household_repository.dart';
import '../data/cat_repository.dart';

/// 猫の登録（S-05）。名前以外は任意（BR-24）。写真はアイコンの実装で足す
class CatFormScreen extends ConsumerStatefulWidget {
  const CatFormScreen({super.key, this.today});

  /// 生年月日に選べる最後の日。テストで日付を固定するために渡す
  final DateTime? today;

  @override
  ConsumerState<CatFormScreen> createState() => _CatFormScreenState();
}

class _CatFormScreenState extends ConsumerState<CatFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _conditions = TextEditingController();
  DateTime? _birthDate;
  CatSex? _sex;
  var _saving = false;

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
    await ref
        .read(catRepositoryProvider)
        .addCat(
          householdId: session.householdId,
          userId: session.author.id,
          name: name,
          birthDate: _birthDate,
          sex: _sex,
          conditions: _conditions.text,
        );
    messenger.showSnackBar(SnackBar(content: Text('$nameを登録しました')));
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    // 画面を開いた時点でセッションを読み込み、読み込むまでは登録できなくする
    final session = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('猫を登録しましょう')),
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
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
