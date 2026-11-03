import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/record_repository.dart';

/// 記録1件を見張る
final recordDetailProvider = StreamProvider.autoDispose
    .family<RecordDetailView?, String>(
      (ref, id) => ref.watch(recordRepositoryProvider).watchRecord(id),
    );
