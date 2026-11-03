import 'package:go_router/go_router.dart';

import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/calendar/presentation/day_records.dart';
import '../features/cats/presentation/cat_form_screen.dart';
import '../features/cats/presentation/cat_list_screen.dart';
import '../features/household/presentation/household_screen.dart';
import '../features/household/presentation/join_screen.dart';
import '../features/records/presentation/record_detail_screen.dart';
import '../features/records/presentation/record_edit_screen.dart';
import '../features/records/presentation/record_types_screen.dart';
import '../features/settings/presentation/contact_screen.dart';
import '../features/sync/presentation/sync_status_screen.dart';
import 'start_screen.dart';

/// 画面の一覧（04 画面設計書）。画面を作るたびに足す
GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/login-help',
      builder: (context, state) => const LoginHelpScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) => const ContactScreen(),
    ),
    GoRoute(
      path: '/join',
      builder: (context, state) =>
          JoinScreen(token: state.uri.queryParameters['token']),
    ),
    GoRoute(
      path: '/household',
      builder: (context, state) => const HouseholdScreen(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const SyncStatusScreen(),
    ),
    GoRoute(
      path: '/cats',
      builder: (context, state) => const CatListScreen(),
      routes: [
        // new を先に置き、猫の ID と見分ける
        GoRoute(
          path: 'new',
          builder: (context, state) => const CatFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              CatProfileScreen(catId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/records/:id',
      builder: (context, state) =>
          RecordDetailScreen(recordId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              RecordEditScreen(recordId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/record-types',
      builder: (context, state) => const RecordTypesScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const RecordTypeFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              RecordTypeFormScreen(typeId: state.pathParameters['id']),
        ),
      ],
    ),
    GoRoute(
      path: '/days/:date',
      builder: (context, state) => DayListScreen(
        // 日付の形が正しくなければ今日にする
        day: DateTime.tryParse(state.pathParameters['date']!) ?? DateTime.now(),
        catId: state.uri.queryParameters['cat'],
      ),
    ),
  ],
);
