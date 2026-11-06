import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../calendar/domain/calendar_month.dart';
import '../../../core/widgets/readable_width.dart';

/// 設定（S-40）
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(weekStartProvider).value ?? WeekStart.sunday;
    // ref.read で読めるよう、ログイン中のユーザーを見張っておく
    ref.watch(authUserProvider);
    final android = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: readablePadding(context, 0),
        children: [
          _Link(label: '猫の一覧とプロフィール', path: '/cats'),
          _Link(label: 'おうちの管理', path: '/household'),
          _Link(label: '記録項目の設定', path: '/record-types'),
          // お薬の予定（S-50）は計画の8で作る。それまでは押せない
          const ListTile(
            title: Text('お薬の予定'),
            subtitle: Text('準備中'),
            enabled: false,
          ),
          _Link(label: '通知の設定', path: '/notification-settings'),
          if (android) _Link(label: 'ウィジェットのボタン', path: '/widget-buttons'),
          _Link(label: 'アカウント', path: '/account'),
          _Link(label: '同期の状態', path: '/sync'),
          _Link(label: '問い合わせ', path: '/contact'),
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
                onSelectionChanged: (s) => ref
                    .read(settingsRepositoryProvider)
                    .setWeekStart(
                      s.first,
                      userId: ref.read(authUserProvider).value?.id,
                    ),
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
