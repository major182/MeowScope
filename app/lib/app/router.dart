import 'package:go_router/go_router.dart';

import '../features/records/presentation/home_screen.dart';

/// 画面の一覧（04 画面設計書）。画面を作るたびに足す
final router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())],
);
