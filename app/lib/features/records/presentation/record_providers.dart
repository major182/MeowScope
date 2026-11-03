import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/record_repository.dart';

/// 記録に使う項目（並び順、削除済みと非表示を除く）。ホームのボタンと統計の選択
final recordTypesProvider = StreamProvider.autoDispose<List<RecordTypeRow>>((
  ref,
) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchTypes(session.householdId);
});

/// 非表示も含めたすべての項目（記録項目の設定と、名前の重なりの確認）
final allRecordTypesProvider = StreamProvider.autoDispose<List<RecordTypeRow>>((
  ref,
) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchTypes(session.householdId, includeHidden: true);
});

/// 記録1件を見張る
final recordDetailProvider = StreamProvider.autoDispose
    .family<RecordDetailView?, String>(
      (ref, id) => ref.watch(recordRepositoryProvider).watchRecord(id),
    );
