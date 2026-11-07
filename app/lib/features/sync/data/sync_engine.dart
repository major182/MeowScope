import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/api/api_error.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/local_cleanup.dart';
import '../../../core/db/tables.dart' show SyncColumns;
import '../../auth/data/auth_repository.dart';
import '../../auth/data/token_store.dart';
import '../../settings/data/settings_repository.dart';

/// 1回の同期の結果
sealed class SyncOutcome {
  const SyncOutcome();
}

class SyncSucceeded extends SyncOutcome {
  const SyncSucceeded({required this.rejected, this.familyRecords = const []});

  /// 今回 `rejected` になった変更の数
  final int rejected;

  /// 今回受け取った、家族（自分以外）の新しい記録（BR-08）。最初の同期と全件の取り直しでは空
  final List<ReceivedRecord> familyRecords;
}

/// 同期で受け取った家族の新しい記録（家族の記録の通知に使う。F-NT-04）
class ReceivedRecord {
  const ReceivedRecord({
    required this.id,
    required this.catId,
    required this.recordTypeId,
    required this.recordedAt,
    required this.authorId,
    required this.authorName,
  });

  final String id;
  final String catId;
  final String recordTypeId;
  final DateTime recordedAt;
  final String? authorId;
  final String authorName;
}

class SyncFailed extends SyncOutcome {
  const SyncFailed(this.error);

  final ApiError error;
}

/// トークンがない・期限が切れた。もう一度ログインしてもらう
class SyncNeedsLogin extends SyncOutcome {
  const SyncNeedsLogin();
}

/// 端末の状態（app_states）に置く同期のキー。ユーザーごとに持つ
abstract final class SyncKeys {
  static String lastSeq(String userId) => 'sync.lastSeq.$userId';
  static String lastSyncedAt(String userId) => 'sync.lastSyncedAt.$userId';
  static String lastRequestId(String userId) => 'sync.lastRequestId.$userId';
}

/// 端末とサーバーの同期（API 設計書 5章、F-OF-01〜03、BR-10、BR-11）
///
/// 1. 端末で作ったおうちを `POST /households` で登録する
/// 2. 同期待ちの行の「今の内容」を丸ごと `POST /sync` で送り、相手の変更を受け取る。
///    同じ行を何度変えても、送るのは最後の内容だけになる
/// 3. 受け取った変更を端末の DB に反映する。まだ送っていない変更がある行は、端末の内容を残す
///    （次の同期で送られ、サーバーで後から受け取った変更として採用される）
///
/// 通信に失敗しても同期待ちは消さないので、記録は失われない（NF-AV-02）。
class SyncEngine {
  SyncEngine(this._db, this._api, this._tokens, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Dio _api;
  final TokenStore _tokens;
  final DateTime Function() _clock;

  /// 1回の要求で送る行の数の上限（API 設計書 5章）
  static const batchSize = 500;

  /// 続きの取得を繰り返す上限。サーバーの誤りで止まらなくなるのを防ぐ
  static const maxRounds = 50;

  /// 今回の同期で受け取った家族の新しい記録
  final _familyRecords = <ReceivedRecord>[];

  /// 今回の同期が最初の同期か（受け取った記録を知らせない）
  var _initialSync = false;

  Future<SyncOutcome> run(String userId) async {
    if (await _tokens.read() == null) {
      return const SyncNeedsLogin();
    }
    var rejected = 0;
    _resyncReceived = null;
    _sentThisRun.clear();
    _familyRecords.clear();
    // 最初の同期（ログイン直後・機種変更）は過去の記録をまとめて受け取るので、家族の記録として知らせない
    _initialSync =
        (int.tryParse(await _state(SyncKeys.lastSeq(userId)) ?? '') ?? 0) == 0;
    try {
      rejected += await _createHouseholds(userId);
      var finished = false;
      for (var round = 0; round < maxRounds; round++) {
        final more = await _round(userId);
        rejected += more.rejected;
        if (!more.again) {
          finished = true;
          break;
        }
      }
      // 全件を取り直し終えたら、受け取らなかった行を端末から消す（途中で止まったときは消さない）
      final received = _resyncReceived;
      if (finished && received != null) {
        await _dropUnreceived(userId, received);
      }
      _resyncReceived = null;
      // 写真の情報を送った後で、画像を送る（API 設計書 6章）
      await _uploadPhotos(userId);
    } on DioException catch (e) {
      final error = ApiError.from(e);
      if (error.status == 401) {
        return const SyncNeedsLogin();
      }
      await _setState(SyncKeys.lastRequestId(userId), error.requestId);
      return SyncFailed(error);
    }
    await _setState(
      SyncKeys.lastSyncedAt(userId),
      _clock().toUtc().toIso8601String(),
    );
    await _setState(SyncKeys.lastRequestId(userId), null);
    await _chooseHousehold(userId);
    return SyncSucceeded(
      rejected: rejected,
      familyRecords: List.unmodifiable(_familyRecords),
    );
  }

  /// 端末で作ったおうちを登録する。標準の項目も ID ごと送る（API 設計書 4章）
  Future<int> _createHouseholds(String userId) async {
    var rejected = 0;
    final creates =
        await (_db.select(_db.pendingChanges)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.targetTable.equals('households') &
                  p.operation.equals('create'),
            ))
            .get();
    for (final pending in creates) {
      final household = await (_db.select(
        _db.households,
      )..where((h) => h.id.equals(pending.rowId))).getSingleOrNull();
      if (household != null) {
        final types = await (_db.select(
          _db.recordTypes,
        )..where((t) => t.householdId.equals(household.id))).get();
        try {
          await _api.post<void>(
            '/households',
            data: {
              'id': household.id,
              'name': household.name,
              'recordTypes': [
                for (final t in types.where((t) => t.kind != 'custom'))
                  {
                    'id': t.id,
                    'name': t.name,
                    'icon': t.icon,
                    'kind': t.kind,
                    'sortOrder': t.sortOrder,
                  },
              ],
            },
          );
        } on DioException catch (e) {
          // 他の人のおうちの ID だった（作り直しの必要がある）。送り直しても結果は変わらない
          if (e.response?.statusCode != 404 && e.response?.statusCode != 400) {
            rethrow;
          }
          rejected++;
          await _reject(
            userId,
            'households',
            pending.rowId,
            e.response?.statusCode == 404 ? 'not_found' : 'invalid',
            null,
          );
        }
      }
      await (_db.delete(
        _db.pendingChanges,
      )..where((p) => p.seq.equals(pending.seq))).go();
    }
    return rejected;
  }

  /// 送信待ちの写真の画像を送る。送れたら送信待ちから外す（端末の画像は30日残す）
  Future<void> _uploadPhotos(String userId) async {
    final waiting = await (_db.select(
      _db.pendingPhotos,
    )..where((p) => p.userId.equals(userId))).get();
    for (final photo in waiting) {
      final file = File(photo.localPath);
      if (await file.exists()) {
        try {
          await _api.put<void>(
            '/photos/${photo.photoId}',
            data: await file.readAsBytes(),
            options: Options(contentType: 'image/jpeg'),
          );
          await (_db.update(_db.recordPhotos)
                ..where((p) => p.id.equals(photo.photoId)))
              .write(const RecordPhotosCompanion(uploaded: Value(true)));
        } on DioException catch (e) {
          final status = e.response?.statusCode ?? 0;
          // 4xx（写真の情報が受け付けられなかった・大きすぎる）は送り直しても変わらない
          if (status < 400 || status >= 500 || status == 401) {
            rethrow;
          }
        }
      }
      await (_db.delete(
        _db.pendingPhotos,
      )..where((p) => p.photoId.equals(photo.photoId))).go();
    }
  }

  /// 送受信を1回行う。続けて呼ぶ必要があれば again が真
  Future<({bool again, int rejected})> _round(String userId) async {
    final pending =
        await (_db.select(_db.pendingChanges)
              ..where(
                (p) =>
                    p.userId.equals(userId) & p.operation.isNotValue('create'),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
            .get();
    // 同じ行の変更は1つにまとめ、送る時点の行の内容を送る
    final rows = <(String, String), List<int>>{};
    for (final p in pending) {
      if (rows.length >= batchSize &&
          !rows.containsKey((p.targetTable, p.rowId))) {
        continue;
      }
      rows.putIfAbsent((p.targetTable, p.rowId), () => []).add(p.seq);
    }
    final changes = <Map<String, Object?>>[];
    final sentSeqs = <int>[];
    for (final MapEntry(key: (table, id), value: seqs) in rows.entries) {
      final change = await _changeOf(table, id, userId);
      sentSeqs.addAll(seqs);
      _sentThisRun.add((table, id));
      if (change != null) {
        changes.add(change);
      }
    }
    final lastSeq =
        int.tryParse(await _state(SyncKeys.lastSeq(userId)) ?? '') ?? 0;
    final Map<String, dynamic> body;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/sync',
        data: {'lastSeq': lastSeq, 'changes': changes},
      );
      body = response.data!;
    } on DioException {
      // 試した回数を残す。同期待ちは消さない
      await (_db.update(
        _db.pendingChanges,
      )..where((p) => p.seq.isIn(sentSeqs))).write(
        PendingChangesCompanion.custom(
          attempts: _db.pendingChanges.attempts + const Constant(1),
        ),
      );
      rethrow;
    }
    final results = (body['results'] as List).cast<Map<String, dynamic>>();
    final rejected = results.where((r) => r['status'] == 'rejected').length;
    // applied・ignored・rejected のどれも、送り直さない。rejected は、どの行がなぜ送れなかったかを残して
    // S-48 に出す（Issue #83）。送れた行は、前に送れなかった記録から外す
    final tables = {
      for (final c in changes) c['id'] as String: c['table'] as String,
    };
    for (final r in results) {
      final id = r['id'] as String;
      final table = tables[id];
      if (table == null) {
        continue;
      }
      if (r['status'] == 'rejected') {
        await _reject(
          userId,
          table,
          id,
          r['reason'] as String? ?? 'unknown',
          r['field'] as String?,
        );
      } else {
        await (_db.delete(_db.rejectedChanges)..where(
              (x) =>
                  x.userId.equals(userId) &
                  x.targetTable.equals(table) &
                  x.rowId.equals(id),
            ))
            .go();
      }
    }
    await (_db.delete(
      _db.pendingChanges,
    )..where((p) => p.seq.isIn(sentSeqs))).go();

    if (body['fullResyncRequired'] == true) {
      await _setState(SyncKeys.lastSeq(userId), '0');
      // ここから受け取る行を数え、取り直し終えたら受け取らなかった行を消す
      _resyncReceived = {};
      return (again: true, rejected: rejected);
    }
    await _apply(
      userId,
      (body['changes'] as List).cast<Map<String, dynamic>>(),
    );
    await _setState(SyncKeys.lastSeq(userId), '${body['nextSeq']}');
    final remaining = pending.length > sentSeqs.length;
    return (again: body['hasMore'] == true || remaining, rejected: rejected);
  }

  /// 送れなかった変更を残す。同じ行の前の記録は置き換える
  Future<void> _reject(
    String userId,
    String table,
    String rowId,
    String reason,
    String? field,
  ) => _db
      .into(_db.rejectedChanges)
      .insertOnConflictUpdate(
        RejectedChangesCompanion.insert(
          userId: userId,
          targetTable: table,
          rowId: rowId,
          reason: reason,
          field: Value(field),
          rejectedAt: _clock().toUtc(),
        ),
      );

  /// 全件の取り直しの間に受け取った行。取り直していないときは null
  Set<(String, String)>? _resyncReceived;

  /// この同期で送った行。受け付けられなかった変更の行も、全件の取り直しの後に消さずに残す（S-48 で何の変更かを出すため）
  final _sentThisRun = <(String, String)>{};

  /// 全件を取り直した後、受け取らなかった行（サーバーにない行）を端末から消す（API 設計書 5章）
  ///
  /// サーバーが削除から90日を過ぎた行を完全に消したときや、サーバーの DB を作り直したときに、
  /// 端末にだけ行が残り続けないようにする。まだ送っていない変更のある行と、サーバーから受け取ったことのない行
  /// （serverSeq が空：端末で作ってまだ送っていない）は残す。参照する側から消す
  Future<void> _dropUnreceived(
    String userId,
    Set<(String, String)> received,
  ) async {
    final pending = {
      for (final p in await (_db.select(
        _db.pendingChanges,
      )..where((p) => p.userId.equals(userId))).get())
        (p.targetTable, p.rowId),
    };
    bool keep(String table, String id) =>
        received.contains((table, id)) ||
        pending.contains((table, id)) ||
        _sentThisRun.contains((table, id));
    // 同期する表は共通の列（SyncColumns）を持つので、id と serverSeq で同じように扱える
    Future<void> drop<T extends SyncColumns, R>(
      String table,
      TableInfo<T, R> info,
    ) async {
      final rows = await (_db.selectOnly(
        info,
      )..addColumns([info.asDslTable.id, info.asDslTable.serverSeq])).get();
      final ids = [
        for (final r in rows)
          if (r.read(info.asDslTable.serverSeq) != null &&
              !keep(table, r.read(info.asDslTable.id)!))
            r.read(info.asDslTable.id)!,
      ];
      if (ids.isEmpty) {
        return;
      }
      await (_db.delete(info)..where((t) => t.id.isIn(ids))).go();
    }

    await _db.transaction(() async {
      await drop('record_photos', _db.recordPhotos);
      await drop('records', _db.records);
      await drop('widget_buttons', _db.widgetButtons);
      await drop('medication_schedules', _db.medicationSchedules);
      await drop('record_types', _db.recordTypes);
      await drop('cats', _db.cats);
      await drop('household_members', _db.householdMembers);
      await drop('households', _db.households);
    });
  }

  /// 送る内容。行がなくなっていれば null
  Future<Map<String, Object?>?> _changeOf(
    String table,
    String id,
    String userId,
  ) async {
    Map<String, Object?> change(
      Map<String, Object?> data, {
      required DateTime updatedAt,
      DateTime? deletedAt,
    }) => {
      'table': table,
      'id': id,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
      'data': data,
    };
    switch (table) {
      case 'households':
        final h = await (_db.select(
          _db.households,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return h == null
            ? null
            : change({'name': h.name}, updatedAt: h.updatedAt);
      case 'cats':
        final c = await (_db.select(
          _db.cats,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return c == null
            ? null
            : change(
                {
                  'householdId': c.householdId,
                  'name': c.name,
                  'birthDate': c.birthDate == null ? null : _date(c.birthDate!),
                  'sex': c.sex,
                  'conditions': c.conditions,
                  'status': c.status,
                  // しきい値（S-47）。行の今の内容を丸ごと送る（ほかの列と同じ）
                  'anomalyThresholds': c.anomalyThresholds == null
                      ? null
                      : jsonDecode(c.anomalyThresholds!),
                },
                updatedAt: c.updatedAt,
                deletedAt: c.deletedAt,
              );
      case 'record_types':
        final t = await (_db.select(
          _db.recordTypes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return t == null
            ? null
            : change(
                {
                  'householdId': t.householdId,
                  'name': t.name,
                  'icon': t.icon,
                  'kind': t.kind,
                  'sortOrder': t.sortOrder,
                  'hidden': t.hidden,
                },
                updatedAt: t.updatedAt,
                deletedAt: t.deletedAt,
              );
      case 'records':
        final r = await (_db.select(
          _db.records,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return r == null
            ? null
            : change(
                {
                  'catId': r.catId,
                  'recordTypeId': r.recordTypeId,
                  'recordedAt': r.recordedAt.toUtc().toIso8601String(),
                  'authorName': r.authorName,
                  'valueNumber': r.valueNumber,
                  'level': r.level,
                  'detail': r.detail == null ? null : _decode(r.detail!),
                  'memo': r.memo,
                },
                updatedAt: r.updatedAt,
                deletedAt: r.deletedAt,
              );
      case 'record_photos':
        final p = await (_db.select(
          _db.recordPhotos,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return p == null
            ? null
            : change(
                {
                  'recordId': p.recordId,
                  'sortOrder': p.sortOrder,
                  'sizeBytes': p.sizeBytes,
                },
                updatedAt: p.updatedAt,
                deletedAt: p.deletedAt,
              );
      case 'user_settings':
        final week = await _state(SettingsRepository.weekStartKey);
        // 通知の設定は、端末で決めたものだけを送る（まだ受け取っていない設定を、既定の値で上書きしないため）
        final flags = await _state(SettingsRepository.notificationsKey);
        final hours = await _state(SettingsRepository.reminderHoursKey);
        final method = await _state(SettingsRepository.anomalyMethodKey);
        return change({
          'weekStart': week ?? 'sunday',
          if (flags != null) 'notifications': jsonDecode(flags),
          if (hours != null) 'reminderHours': int.tryParse(hours),
          'anomalyMethod': ?method,
        }, updatedAt: _clock());
      case 'widget_buttons':
        final w = await (_db.select(
          _db.widgetButtons,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return w == null
            ? null
            : change(
                {'recordTypeId': w.recordTypeId, 'sortOrder': w.sortOrder},
                updatedAt: w.updatedAt,
                deletedAt: w.deletedAt,
              );
      case 'medication_schedules':
        final m = await (_db.select(
          _db.medicationSchedules,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return m == null
            ? null
            : change(
                {
                  'householdId': m.householdId,
                  'catId': m.catId,
                  'name': m.name,
                  'dose': m.dose,
                  'timeOfDay': m.timeOfDay,
                  'enabled': m.enabled,
                },
                updatedAt: m.updatedAt,
                deletedAt: m.deletedAt,
              );
    }
    return null;
  }

  /// 受け取った変更を反映する
  ///
  /// 番号の順に届くので、記録が猫より先に届くこともある（猫を後で変えると番号が新しくなる）。
  /// 参照の確認を止めてから反映し、サーバーの側で正しさを保証する
  Future<void> _apply(String userId, List<Map<String, dynamic>> changes) async {
    if (changes.isEmpty) {
      return;
    }
    final pendingRows = {
      for (final p in await (_db.select(
        _db.pendingChanges,
      )..where((p) => p.userId.equals(userId))).get())
        (p.targetTable, p.rowId),
    };
    final left = <String>{};
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        for (final c in changes) {
          final table = c['table'] as String;
          final id = c['id'] as String;
          _resyncReceived?.add((table, id));
          if (pendingRows.contains((table, id))) {
            continue;
          }
          final data = (c['data'] as Map).cast<String, dynamic>();
          final updatedAt = _time(c['updatedAt']) ?? _clock().toUtc();
          final deletedAt = _time(c['deletedAt']);
          final seq = c['seq'] as int?;
          switch (table) {
            case 'households':
              await _db
                  .into(_db.households)
                  .insertOnConflictUpdate(
                    HouseholdsCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      name: data['name'] as String,
                    ),
                  );
            case 'household_members':
              final member = data['userId'] as String?;
              await _db
                  .into(_db.householdMembers)
                  .insertOnConflictUpdate(
                    HouseholdMembersCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      householdId: data['householdId'] as String,
                      userId: Value(member),
                      displayName: Value(data['displayName'] as String?),
                    ),
                  );
              if (member == userId && deletedAt != null) {
                left.add(data['householdId'] as String);
              }
            case 'users':
              await (_db.update(
                _db.householdMembers,
              )..where((m) => m.userId.equals(id))).write(
                HouseholdMembersCompanion(
                  displayName: Value(data['displayName'] as String?),
                  hasIcon: Value(data['hasIcon'] as bool? ?? false),
                  iconSeq: Value(seq),
                ),
              );
            case 'cats':
              await _db
                  .into(_db.cats)
                  .insertOnConflictUpdate(
                    CatsCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      householdId: data['householdId'] as String,
                      name: data['name'] as String,
                      birthDate: Value(
                        data['birthDate'] == null
                            ? null
                            : DateTime.parse(data['birthDate'] as String),
                      ),
                      sex: Value(data['sex'] as String?),
                      conditions: Value(data['conditions'] as String?),
                      status: Value(data['status'] as String? ?? 'active'),
                      hasIcon: Value(data['hasIcon'] as bool? ?? false),
                      anomalyThresholds: Value(
                        data['anomalyThresholds'] is Map
                            ? jsonEncode(data['anomalyThresholds'])
                            : null,
                      ),
                    ),
                  );
            case 'record_types':
              await _db
                  .into(_db.recordTypes)
                  .insertOnConflictUpdate(
                    RecordTypesCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      householdId: data['householdId'] as String,
                      name: data['name'] as String,
                      icon: Value(data['icon'] as String?),
                      kind: data['kind'] as String,
                      sortOrder: Value(data['sortOrder'] as int? ?? 0),
                      hidden: Value(data['hidden'] as bool? ?? false),
                    ),
                  );
            case 'records':
              final authorId = data['authorId'] as String?;
              // 家族の新しい記録か（BR-08）。全件の取り直しの間は、もう持っている記録も届くので知らせない
              if (!_initialSync &&
                  _resyncReceived == null &&
                  deletedAt == null &&
                  authorId != userId &&
                  await (_db.select(
                        _db.records,
                      )..where((r) => r.id.equals(id))).getSingleOrNull() ==
                      null) {
                _familyRecords.add(
                  ReceivedRecord(
                    id: id,
                    catId: data['catId'] as String,
                    recordTypeId: data['recordTypeId'] as String,
                    recordedAt: DateTime.parse(data['recordedAt'] as String),
                    authorId: authorId,
                    authorName: data['authorName'] as String,
                  ),
                );
              }
              await _db
                  .into(_db.records)
                  .insertOnConflictUpdate(
                    RecordsCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      catId: data['catId'] as String,
                      recordTypeId: data['recordTypeId'] as String,
                      recordedAt: DateTime.parse(data['recordedAt'] as String),
                      authorId: Value(data['authorId'] as String?),
                      authorName: data['authorName'] as String,
                      valueNumber: Value(
                        (data['valueNumber'] as num?)?.toDouble(),
                      ),
                      level: Value(data['level'] as String?),
                      detail: Value(
                        data['detail'] == null
                            ? null
                            : jsonEncode(data['detail']),
                      ),
                      memo: Value(data['memo'] as String?),
                    ),
                  );
            case 'record_photos':
              await _db
                  .into(_db.recordPhotos)
                  .insertOnConflictUpdate(
                    RecordPhotosCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      recordId: data['recordId'] as String,
                      sortOrder: data['sortOrder'] as int,
                      sizeBytes: Value(data['sizeBytes'] as int?),
                      uploaded: Value(data['uploaded'] as bool? ?? false),
                    ),
                  );
            case 'user_settings':
              final week = data['weekStart'] as String?;
              if (week != null) {
                await _setState(SettingsRepository.weekStartKey, week);
              }
              // 通知の設定（S-49）。サーバーに値があるものだけを置く
              final flags = data['notifications'];
              if (flags is Map) {
                await _setState(
                  SettingsRepository.notificationsKey,
                  jsonEncode(flags),
                );
              }
              final hours = data['reminderHours'];
              if (hours is int) {
                await _setState(SettingsRepository.reminderHoursKey, '$hours');
              }
              final method = data['anomalyMethod'] as String?;
              if (method != null) {
                await _setState(SettingsRepository.anomalyMethodKey, method);
              }
            case 'widget_buttons':
              await _db
                  .into(_db.widgetButtons)
                  .insertOnConflictUpdate(
                    WidgetButtonsCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      userId: userId,
                      recordTypeId: data['recordTypeId'] as String,
                      sortOrder: Value(data['sortOrder'] as int? ?? 0),
                    ),
                  );
            case 'medication_schedules':
              await _db
                  .into(_db.medicationSchedules)
                  .insertOnConflictUpdate(
                    MedicationSchedulesCompanion.insert(
                      id: id,
                      createdAt: updatedAt,
                      updatedAt: updatedAt,
                      deletedAt: Value(deletedAt),
                      serverSeq: Value(seq),
                      householdId: data['householdId'] as String,
                      catId: data['catId'] as String,
                      name: data['name'] as String,
                      dose: Value(data['dose'] as String?),
                      timeOfDay: data['timeOfDay'] as String,
                      enabled: Value(data['enabled'] as bool? ?? true),
                    ),
                  );
          }
        }
        for (final household in left) {
          await removeHouseholdLocally(_db, userId, household);
        }
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  /// おうちを選んでいなければ、属しているおうちを選ぶ（機種変更の後など。S-04 を出さずに済む）
  Future<void> _chooseHousehold(String userId) async {
    if (await _state(SessionKeys.householdId) != null) {
      return;
    }
    final member =
        await (_db.select(_db.householdMembers)
              ..where(
                (m) =>
                    m.userId.equals(userId) &
                    m.deletedAt.isNull() &
                    m.householdId.isInQuery(
                      _db.selectOnly(_db.households)
                        ..addColumns([_db.households.id])
                        ..where(_db.households.deletedAt.isNull()),
                    ),
              )
              ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (member != null) {
      await _setState(SessionKeys.householdId, member.householdId);
      await _setState(SessionKeys.householdOf(userId), member.householdId);
    }
  }

  Future<String?> _state(String key) async => (await (_db.select(
    _db.appStates,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setState(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.appStates)..where((s) => s.key.equals(key))).go();
    } else {
      await _db
          .into(_db.appStates)
          .insertOnConflictUpdate(
            AppStatesCompanion.insert(key: key, value: value),
          );
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
