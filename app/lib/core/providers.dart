import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/token_store.dart';
import '../features/calendar/domain/calendar_month.dart';
import '../features/cats/data/cat_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/records/data/record_repository.dart';
import '../features/settings/data/settings_repository.dart';
import 'api/api_client.dart';
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
