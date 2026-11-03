import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../data/sync_engine.dart';

/// 同期の状態（画面に出すもの）
class SyncState {
  const SyncState({this.running = false, this.error, this.needsLogin = false});

  final bool running;

  /// 前回の失敗。成功したら消える
  final ApiError? error;

  /// ログインの期限が切れた
  final bool needsLogin;
}

/// 同期を実行する。端末では同時に1つだけ実行する（API 設計書 5章）
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> sync() async {
    final user = ref.read(authUserProvider).value;
    if (state.running || user == null) {
      return;
    }
    state = SyncState(running: true, needsLogin: state.needsLogin);
    SyncOutcome outcome;
    try {
      outcome = await ref.read(syncEngineProvider).run(user.id);
    } on Exception {
      // 想定外の失敗でも、アプリの操作は止めない。同期待ちは残っているので次に送る
      outcome = const SyncFailed(ApiError(status: 500));
    }
    if (!ref.mounted) {
      return;
    }
    state = switch (outcome) {
      SyncSucceeded() => const SyncState(),
      SyncFailed(:final error) => SyncState(error: error),
      SyncNeedsLogin() => const SyncState(needsLogin: true),
    };
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// S-46 とホームに出す同期の情報
class SyncInfo {
  const SyncInfo({
    required this.lastSyncedAt,
    required this.pending,
    required this.rejected,
    required this.lastRequestId,
  });

  final DateTime? lastSyncedAt;

  /// まだ送っていない変更の数（同じ行の変更は1つに数える）
  final int pending;
  final int rejected;
  final String? lastRequestId;
}

final syncInfoProvider = StreamProvider<SyncInfo>((ref) {
  final user = ref.watch(authUserProvider).value;
  final db = ref.watch(databaseProvider);
  if (user == null) {
    return Stream.value(
      const SyncInfo(
        lastSyncedAt: null,
        pending: 0,
        rejected: 0,
        lastRequestId: null,
      ),
    );
  }
  // 未送信の件数か同期の状態が変わるたびに、両方を読み直す
  final pendingQuery = db.select(db.pendingChanges)
    ..where((p) => p.userId.equals(user.id));
  return pendingQuery.watch().asyncMap((pending) async {
    final states = {
      for (final s in await db.select(db.appStates).get()) s.key: s.value,
    };
    return SyncInfo(
      lastSyncedAt: DateTime.tryParse(
        states[SyncKeys.lastSyncedAt(user.id)] ?? '',
      )?.toLocal(),
      pending: {for (final p in pending) (p.targetTable, p.rowId)}.length,
      rejected: int.tryParse(states[SyncKeys.rejected(user.id)] ?? '') ?? 0,
      lastRequestId: states[SyncKeys.lastRequestId(user.id)],
    );
  });
});

/// 自動の同期（F-OF-03）：表示したとき（起動時）、バックグラウンドへ移るとき、実行中は5分おき
class SyncScheduler extends ConsumerStatefulWidget {
  const SyncScheduler({super.key, required this.child});

  final Widget child;

  /// 実行中に同期する間隔
  static const interval = Duration(minutes: 5);

  @override
  ConsumerState<SyncScheduler> createState() => _SyncSchedulerState();
}

class _SyncSchedulerState extends ConsumerState<SyncScheduler> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // 最初の表示が終わってから始める（表示の途中で状態を変えないため）
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    // 30日を過ぎた写真を端末から消す（AC-14）。起動のたびに確かめる
    ref.read(photoRepositoryProvider).cleanupOld();
    _timer = Timer.periodic(SyncScheduler.interval, (_) => _sync());
    _lifecycle = AppLifecycleListener(onHide: _sync);
  }

  void _sync() {
    if (mounted) {
      ref.read(syncControllerProvider.notifier).sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.read で読めるよう、ログイン中のユーザーを見張っておく
    ref.watch(authUserProvider);
    return widget.child;
  }
}
