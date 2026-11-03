import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/cats/data/cat_repository.dart';
import '../features/household/data/household_repository.dart';
import '../features/records/data/record_repository.dart';
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
