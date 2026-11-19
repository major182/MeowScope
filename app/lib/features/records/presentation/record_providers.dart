import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/record_repository.dart';
import '../domain/type_order.dart';
import '../domain/vet_detail.dart';

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

/// この端末の記録項目の並び順（F-RC-07）。並べ替えていなければ空
final typeOrderProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(settingsRepositoryProvider)
      .watchTypeOrder(session.householdId);
});

/// 記録のボタン（ホーム・日付からの記録）の項目を、端末の並び順で並べる（BR-36）。
/// 統計の選択とカレンダーの印は登録の順のまま（recordTypesProvider）
final orderedRecordTypesProvider =
    Provider.autoDispose<AsyncValue<List<RecordTypeRow>>>((ref) {
      final order = ref.watch(typeOrderProvider).value ?? const [];
      return ref
          .watch(recordTypesProvider)
          .whenData((types) => applyTypeOrder(types, order, (t) => t.id));
    });

/// 記録項目の設定（S-43）の一覧。非表示も含め、端末の並び順で並べる
final orderedAllRecordTypesProvider =
    Provider.autoDispose<AsyncValue<List<RecordTypeRow>>>((ref) {
      final order = ref.watch(typeOrderProvider).value ?? const [];
      return ref
          .watch(allRecordTypesProvider)
          .whenData((types) => applyTypeOrder(types, order, (t) => t.id));
    });

/// おうちの病院の記録（新しい順）。名前の候補とカレンダーの予定の印に使う（F-MD-01）
final vetRecordsProvider = StreamProvider.autoDispose<List<RecordEntry>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchVetRecords(session.householdId);
});

/// 病院の名前の候補（同じおうちで前に入れた名前。新しく使った順）
final hospitalNamesProvider = Provider.autoDispose<List<String>>(
  (ref) => hospitalSuggestions([
    for (final e
        in ref.watch(vetRecordsProvider).value ?? const <RecordEntry>[])
      e.detail,
  ]),
);

/// 猫ごとの病院の履歴（新しい順。猫のプロフィール S-41）
final catVetHistoryProvider = StreamProvider.autoDispose
    .family<List<RecordEntry>, String>((ref, catId) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(recordRepositoryProvider)
          .watchVetRecords(session.householdId, catId: catId);
    });
