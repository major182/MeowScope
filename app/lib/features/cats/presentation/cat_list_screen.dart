import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../icons/icon_avatar.dart';
import '../../icons/icon_repository.dart';
import '../data/cat_repository.dart';
import 'cat_filter.dart';

/// 猫の一覧（S-41）。お別れの猫も出す
class CatListScreen extends ConsumerWidget {
  const CatListScreen({super.key, this.today});

  /// 年齢の計算に使う今日。テストで差し替える
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(filterCatsProvider).value ?? const [];
    final now = today ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('猫'),
        actions: [
          TextButton(
            onPressed: () => context.push('/cats/new'),
            child: const Text('追加'),
          ),
        ],
      ),
      body: cats.isEmpty
          ? const Center(child: Text('猫が登録されていません'))
          : ListView(
              children: [
                for (final c in cats)
                  ListTile(
                    leading: IconAvatar(
                      icon: IconRef(
                        IconOwner.cat,
                        c.id,
                        hasIcon: c.hasIcon,
                        version: c.serverSeq,
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      c.status == 'farewell'
                          ? 'お別れ'
                          : ageLabel(c.birthDate?.toUtc(), now) ?? '',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/cats/${c.id}'),
                  ),
              ],
            ),
    );
  }
}
