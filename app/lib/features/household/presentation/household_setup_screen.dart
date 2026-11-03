import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

/// おうちの作成（S-04）
///
/// 「あなたの名前」は、ログインができるまでの仮の欄。記録の投稿者名に使う（BR-17）。
/// 認証の実装で、新規登録の画面へ移す。招待されたおうちへの参加は、招待の実装で足す
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _householdName = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _userName.dispose();
    _householdName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    await ref
        .read(householdRepositoryProvider)
        .createHousehold(
          householdName: _householdName.text,
          userName: _userName.text,
        );
    // おうちができたら、続けて最初の猫を登録する（S-05）
    router.push('/cats/new');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('おうちを準備します')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _userName,
              decoration: const InputDecoration(labelText: 'あなたの名前'),
              validator: _required('あなたの名前'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _householdName,
              decoration: const InputDecoration(labelText: 'おうちの名前'),
              validator: _required('おうちの名前'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: const Text('新しいおうちを作る'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空欄と空白だけの入力を受け付けない
FormFieldValidator<String> _required(String label) =>
    (value) => (value?.trim().isEmpty ?? true) ? '$labelを入力してください' : null;
