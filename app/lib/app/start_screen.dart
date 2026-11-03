import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/household/presentation/household_setup_screen.dart';
import '../features/records/presentation/home_screen.dart';

/// 最初の画面。おうちがあればホーム、なければおうちの作成を出す
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sessionProvider)
        .when(
          data: (session) => session == null
              ? const HouseholdSetupScreen()
              : const HomeScreen(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => const Scaffold(
            body: Center(child: Text('データを読み込めませんでした。アプリを開き直してください')),
          ),
        );
  }
}
