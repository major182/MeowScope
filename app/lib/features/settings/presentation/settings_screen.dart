import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../calendar/domain/calendar_month.dart';

/// 設定（S-40）
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(weekStartProvider).value ?? WeekStart.sunday;
    final android = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _Link(label: '猫の一覧とプロフィール', path: '/cats'),
          const _Pending(label: 'おうちの管理'),
          _Link(label: '記録項目の設定', path: '/record-types'),
          if (android) const _Pending(label: 'ウィジェットのボタン'),
          const _Pending(label: 'アカウント'),
          const _Pending(label: '同期の状態'),
          const _Pending(label: '問い合わせ'),
          const Divider(),
          ListTile(
            title: const Text('カレンダーの週の始まり'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<WeekStart>(
                segments: const [
                  ButtonSegment(value: WeekStart.sunday, label: Text('日曜')),
                  ButtonSegment(value: WeekStart.monday, label: Text('月曜')),
                ],
                selected: {weekStart},
                onSelectionChanged: (s) =>
                    ref.read(settingsRepositoryProvider).setWeekStart(s.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 別の画面へ進む項目
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
  }
}

/// まだ作っていない画面の項目。押せないようにして「準備中」と出す
class _Pending extends StatelessWidget {
  const _Pending({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      title: Text(label),
      subtitle: const Text('準備中'),
    );
  }
}
