import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// ログイン中のユーザーと、選んでいるおうち
class Session {
  const Session({required this.author, required this.householdId});

  final Author author;
  final String householdId;
}

/// ログインとおうちの選択は、認証の実装で埋める。それまでは常に空
final sessionProvider = Provider<Session?>((ref) => null);
