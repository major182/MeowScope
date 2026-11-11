import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../notifications/data/family_alerts.dart';
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
    var unexpected = false;
    try {
      outcome = await ref.read(syncEngineProvider).run(user.id);
    } catch (e) {
      // 想定外の失敗（壊れた応答による型の誤りなども）でも、アプリの操作は止めない。同期待ちは残っているので次に送る
      // ログには例外の種類だけを書く（内容に記録が含まれるおそれがあるため。ログ設計書 6章）
      if (ref.mounted) {
        await ref
            .read(appLogProvider)
            .record('error', '同期で想定外の例外：${e.runtimeType}');
      }
      unexpected = true;
      outcome = const SyncFailed(ApiError(status: 500));
    }
    // 同期の間にこの部品が捨てられた（ログアウトなど）なら、ここで終える。捨てられた後は ref を使えない（Issue #145）
    if (!ref.mounted) {
      return;
    }
    final log = ref.read(appLogProvider);
    switch (outcome) {
      case SyncSucceeded(:final familyRecords):
        // 同期できたときに、たまっている端末のログも送る（F-LG-03）
        await log.send(ref.read(apiClientProvider));
        if (familyRecords.isNotEmpty && ref.mounted) {
          await _notifyFamily(familyRecords);
        }
      case SyncFailed(:final error) when !error.isOffline && !unexpected:
        // つながらないのはよくあることなので記録しない。サーバーの応答があった失敗だけを残す
        await log.record(
          error.isServerError ? 'error' : 'warning',
          '同期に失敗（状態コード：${error.status}、${error.code ?? '-'}）',
          requestId: error.requestId,
        );
      default:
        break;
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

  /// 受け取った家族の記録を知らせる（F-NT-04、BR-08）。失敗しても同期の結果は変えない
  Future<void> _notifyFamily(List<ReceivedRecord> records) async {
    try {
      final settings = await ref.read(notificationSettingsProvider.future);
      await ref
          .read(familyAlertsProvider)
          .notify(
            records,
            settings: settings,
            android: defaultTargetPlatform == TargetPlatform.android,
          );
    } on Object catch (e) {
      // 例外の種類だけをログに残す
      await ref
          .read(appLogProvider)
          .record('warning', '家族の記録の通知に失敗：${e.runtimeType}');
    }
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
  // 未送信・送れなかった変更・同期の状態のどれかが変わるたびに、すべてを読み直す
  final changed = db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          db.pendingChanges,
          db.rejectedChanges,
          db.appStates,
        ]),
      )
      .map((_) {});
  Stream<void> ticks() async* {
    yield null;
    yield* changed;
  }

  return ticks().asyncMap((_) async {
    final pending = await (db.select(
      db.pendingChanges,
    )..where((p) => p.userId.equals(user.id))).get();
    final rejected = await (db.select(
      db.rejectedChanges,
    )..where((r) => r.userId.equals(user.id))).get();
    final states = {
      for (final s in await db.select(db.appStates).get()) s.key: s.value,
    };
    return SyncInfo(
      lastSyncedAt: DateTime.tryParse(
        states[SyncKeys.lastSyncedAt(user.id)] ?? '',
      )?.toLocal(),
      pending: {for (final p in pending) (p.targetTable, p.rowId)}.length,
      rejected: rejected.length,
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
    // 待たずに進める。失敗しても次の起動でまた確かめるので、例外の種類だけをログに残す
    final log = ref.read(appLogProvider);
    unawaited(
      ref
          .read(photoRepositoryProvider)
          .cleanupOld()
          .then<void>(
            (_) {},
            onError: (Object e) =>
                log.record('warning', '古い写真の片付けに失敗：${e.runtimeType}'),
          ),
    );
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
