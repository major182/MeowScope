import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../records/data/record_repository.dart';

/// 期間の記録を見張る（from 以上 to 未満。catId が null なら全員）
final rangeRecordsProvider = StreamProvider.autoDispose
    .family<List<RecordEntry>, ({DateTime from, DateTime to, String? catId})>((
      ref,
      key,
    ) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(recordRepositoryProvider)
          .watchRange(
            session.householdId,
            from: key.from,
            to: key.to,
            catId: key.catId,
          );
    });
