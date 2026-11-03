import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/record_repository.dart';

/// おうちの記録項目（並び順、削除済みを除く）
final recordTypesProvider = StreamProvider.autoDispose<List<RecordTypeRow>>((
  ref,
) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchTypes(session.householdId);
});

/// 記録1件を見張る
final recordDetailProvider = StreamProvider.autoDispose
    .family<RecordDetailView?, String>(
      (ref, id) => ref.watch(recordRepositoryProvider).watchRecord(id),
    );
