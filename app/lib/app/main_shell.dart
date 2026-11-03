import 'package:flutter/material.dart';

import '../features/calendar/presentation/calendar_screen.dart';
import '../features/records/presentation/home_screen.dart';

/// この幅以上なら左にメニューを置く（Windows 向け。04 画面設計書 1章）
const wideLayoutWidth = 900.0;

/// メニューの1項目
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('ホーム', Icons.home_outlined, Icons.home),
  _Destination('カレンダー', Icons.calendar_month_outlined, Icons.calendar_month),
  _Destination('統計', Icons.bar_chart_outlined, Icons.bar_chart),
  _Destination('設定', Icons.settings_outlined, Icons.settings),
];

/// ホーム・カレンダー・統計・設定を切り替える枠。
/// 狭い幅は下部メニュー、広い幅は左メニューにする
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // 切り替えても各画面の状態（スクロールの位置など）を残す
    final body = IndexedStack(
      index: _index,
      children: const [
        HomeScreen(),
        CalendarScreen(),
        PlaceholderScreen(title: '統計'),
        PlaceholderScreen(title: '設定'),
      ],
    );
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// まだ作っていない画面の仮の表示
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('準備中です')),
    );
  }
}
