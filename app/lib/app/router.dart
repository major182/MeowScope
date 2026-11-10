import 'package:go_router/go_router.dart';

import '../features/stats/presentation/stats_screen.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
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
import '../features/sync/presentation/rejected_changes_screen.dart';
import '../features/medication/presentation/medication_form_screen.dart';
import '../features/medication/presentation/medication_schedules_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/notifications/presentation/thresholds_screen.dart';
import '../features/sync/presentation/sync_status_screen.dart';
import '../features/widget/presentation/widget_buttons_screen.dart';
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
      routes: [
        GoRoute(
          path: 'password-reset',
          builder: (context, state) => const PasswordResetScreen(),
        ),
      ],
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
      routes: [
        GoRoute(
          path: 'rejected',
          builder: (context, state) => const RejectedChangesScreen(),
        ),
      ],
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
      path: '/notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/medications',
      builder: (context, state) => const MedicationSchedulesScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const MedicationFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              MedicationFormScreen(scheduleId: state.pathParameters['id']),
        ),
      ],
    ),
    GoRoute(
      path: '/thresholds',
      builder: (context, state) => const ThresholdsScreen(),
    ),
    GoRoute(
      path: '/widget-buttons',
      builder: (context, state) => const WidgetButtonsScreen(),
    ),
    GoRoute(
      // いつもとの差の通知から開く統計（S-30）。ふだんはメニューの統計を使う
      path: '/stats',
      builder: (context, state) => StatsScreen(
        catId: state.uri.queryParameters['cat'],
        kind: state.uri.queryParameters['kind'],
      ),
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
