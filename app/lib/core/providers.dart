import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../features/auth/data/account_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/token_store.dart';
import '../features/calendar/domain/calendar_month.dart';
import '../features/cats/data/cat_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/records/data/record_repository.dart';
import '../features/icons/icon_repository.dart';
import '../features/notifications/data/notifier.dart';
import '../features/notifications/domain/notification_settings.dart';
import '../features/photos/data/photo_picker.dart';
import '../features/photos/data/photo_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/sync/data/sync_engine.dart';
import '../features/widget/data/widget_button_repository.dart';
import 'api/api_client.dart';
import 'logging/app_log.dart';
import 'db/app_database.dart';

/// 端末内 DB。テストではメモリー上の DB に差し替える
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final recordRepositoryProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(databaseProvider)),
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(
    ref.watch(databaseProvider),
    ref.watch(recordRepositoryProvider),
  ),
);

final widgetButtonRepositoryProvider = Provider<WidgetButtonRepository>(
  (ref) => WidgetButtonRepository(ref.watch(databaseProvider)),
);

final catRepositoryProvider = Provider<CatRepository>(
  (ref) => CatRepository(ref.watch(databaseProvider)),
);

/// ログイン中のユーザーと選んでいるおうち。おうちがまだなければ null
final sessionProvider = StreamProvider<Session?>(
  (ref) => ref.watch(householdRepositoryProvider).watchSession(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// カレンダーの週の始まり
final weekStartProvider = StreamProvider<WeekStart>(
  (ref) => ref.watch(settingsRepositoryProvider).watchWeekStart(),
);

/// トークンの保管場所。テストではメモリーに置く版に差し替える
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// サーバーの API を呼ぶ通信の部品。テストでは偽のサーバーにつなぐ
final apiClientProvider = Provider<Dio>(
  (ref) => createApiClient(tokens: ref.watch(tokenStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

/// ログイン中のユーザー。ログインしていなければ null
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

/// 写真を置くフォルダー（端末のアプリ用フォルダーの下）。テストでは一時フォルダーに差し替える
final photoDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory('${(await getApplicationSupportDirectory()).path}/photos'),
);

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(
    ref.watch(databaseProvider),
    ref.watch(photoDirectoryProvider),
  ),
);

/// 写真を選ぶ部品。テストでは決めた画像を返す版に差し替える
final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

/// 端末のログ（ログ設計書 8章）
final appLogProvider = Provider<AppLog>(
  (ref) => AppLog(ref.watch(databaseProvider)),
);

/// 問い合わせ用のログをファイルに保存し、保存した場所を返す（S-06）。テストでは差し替える
///
/// Windows は「ダウンロード」、Android はアプリの文書のフォルダーに置く
final logFileSaverProvider = Provider<Future<String> Function(String text)>(
  (ref) => (text) async {
    final dir =
        (Platform.isWindows ? await getDownloadsDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final file = File(
      '${dir.path}${Platform.pathSeparator}meowscope-log-$stamp.txt',
    );
    await file.writeAsString(text, flush: true);
    return file.path;
  },
);

final iconRepositoryProvider = Provider<IconRepository>(
  (ref) => IconRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(photoDirectoryProvider),
  ),
);

/// 通知を出す部品（BR-09）。Android は起動時に OS の通知の版へ差し替える（main.dart）。
/// それ以外（Windows・テスト）はアプリの画面の中で知らせる版
final notifierProvider = Provider<AppNotifier>((ref) => InAppNotifier());

/// 通知の設定（S-49）
final notificationSettingsProvider = StreamProvider<NotificationSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchNotificationSettings(),
);
