import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/api/api_error.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/local_cleanup.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/token_store.dart';
import '../../settings/data/settings_repository.dart';

/// 1回の同期の結果
sealed class SyncOutcome {
  const SyncOutcome();
}

class SyncSucceeded extends SyncOutcome {
  const SyncSucceeded({required this.rejected});

  /// 今回 `rejected` になった変更の数
  final int rejected;
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
  static String rejected(String userId) => 'sync.rejected.$userId';
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

  Future<SyncOutcome> run(String userId) async {
    if (await _tokens.read() == null) {
      return const SyncNeedsLogin();
    }
    var rejected = 0;
    try {
      rejected += await _createHouseholds(userId);
      for (var round = 0; round < maxRounds; round++) {
        final more = await _round(userId);
        rejected += more.rejected;
        if (!more.again) {
          break;
        }
      }
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
    if (rejected > 0) {
      final before = int.tryParse(
        await _state(SyncKeys.rejected(userId)) ?? '',
      );
      await _setState(SyncKeys.rejected(userId), '${(before ?? 0) + rejected}');
    }
    await _chooseHousehold(userId);
    return SyncSucceeded(rejected: rejected);
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
    // applied・ignored・rejected のどれも、送り直さない（rejected は件数だけを S-46 に出す）
    await (_db.delete(
      _db.pendingChanges,
    )..where((p) => p.seq.isIn(sentSeqs))).go();

    if (body['fullResyncRequired'] == true) {
      await _setState(SyncKeys.lastSeq(userId), '0');
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
        return change({'weekStart': week ?? 'sunday'}, updatedAt: _clock());
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
