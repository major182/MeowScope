import 'package:go_router/go_router.dart';

import '../features/cats/presentation/cat_form_screen.dart';
import 'start_screen.dart';

/// 画面の一覧（04 画面設計書）。画面を作るたびに足す
GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartScreen()),
    GoRoute(
      path: '/cats/new',
      builder: (context, state) => const CatFormScreen(),
    ),
  ],
);
