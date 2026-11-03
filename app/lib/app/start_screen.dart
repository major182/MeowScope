import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/household/presentation/household_setup_screen.dart';
import 'main_shell.dart';

/// 最初の画面。ログインしていなければログイン（S-01）、おうちがなければおうちの作成（S-04）、
/// どちらもあればホームを出す
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final session = ref.watch(sessionProvider);
    if (user.hasError || session.hasError) {
      return const Scaffold(
        body: Center(child: Text('データを読み込めませんでした。アプリを開き直してください')),
      );
    }
    if (!user.hasValue || !session.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user.value == null) {
      return const LoginScreen();
    }
    return session.value == null
        ? const HouseholdSetupScreen()
        : const MainShell();
  }
}
