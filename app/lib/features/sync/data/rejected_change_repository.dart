import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

/// 送れなかった変更1件（S-48）
class RejectedChangeView {
  const RejectedChangeView({
    required this.table,
    required this.rowId,
    required this.reason,
    required this.field,
    required this.rejectedAt,
    required this.label,
    required this.recordId,
  });

  final String table;
  final String rowId;
  final String reason;
  final String? field;
  final DateTime rejectedAt;

  /// 何の変更か（例：「11/05 08:10 ミケのご飯」）
  final String label;

  /// 開ける記録の ID。記録とその写真のときで、記録が端末に残っていれば入る
  final String? recordId;
}

/// 送れなかった変更（Issue #83）。どの変更かを利用者に分かる言葉にし、送り直しと一覧からの削除を行う
class RejectedChangeRepository {
  RejectedChangeRepository(this._db);

  final AppDatabase _db;

  /// 自分の送れなかった変更を、新しい順に見張る
  Stream<List<RejectedChangeView>> watch(String userId) {
    final q = _db.select(_db.rejectedChanges)
      ..where((r) => r.userId.equals(userId))
      ..orderBy([(r) => OrderingTerm.desc(r.rejectedAt)]);
    return q.watch().asyncMap(
      (rows) async => [for (final r in rows) await _view(r)],
    );
  }

  Future<RejectedChangeView> _view(RejectedChangeRow r) async {
    final (label, recordId) = await _describe(r.targetTable, r.rowId);
    return RejectedChangeView(
      table: r.targetTable,
      rowId: r.rowId,
      reason: r.reason,
      field: r.field,
      rejectedAt: r.rejectedAt,
      label: label,
      recordId: recordId,
    );
  }

  /// 何の変更かと、開ける記録の ID
  Future<(String, String?)> _describe(String table, String id) async {
    switch (table) {
      case 'records':
        final text = await _recordLabel(id);
        return text == null ? ('削除された記録', null) : (text, id);
      case 'record_photos':
        final photo = await (_db.select(
          _db.recordPhotos,
        )..where((p) => p.id.equals(id))).getSingleOrNull();
        final text = photo == null ? null : await _recordLabel(photo.recordId);
        return text == null ? ('記録の写真', null) : ('写真（$text）', photo!.recordId);
      case 'cats':
        final cat = await (_db.select(
          _db.cats,
        )..where((c) => c.id.equals(id))).getSingleOrNull();
        return ('猫：${cat?.name ?? '削除された猫'}', null);
      case 'record_types':
        final type = await _typeName(id);
        return ('記録項目：${type ?? '削除された項目'}', null);
      case 'widget_buttons':
        final button = await (_db.select(
          _db.widgetButtons,
        )..where((w) => w.id.equals(id))).getSingleOrNull();
        final type = button == null
            ? null
            : await _typeName(button.recordTypeId);
        return ('ウィジェットのボタン：${type ?? '削除されたボタン'}', null);
      case 'households':
        final household = await (_db.select(
          _db.households,
        )..where((h) => h.id.equals(id))).getSingleOrNull();
        return ('おうち：${household?.name ?? '削除されたおうち'}', null);
      case 'user_settings':
        return ('設定（カレンダーの週の始まり）', null);
    }
    return ('その他のデータ', null);
  }

  /// 「11/05 08:10 ミケのご飯」。記録がなければ null
  Future<String?> _recordLabel(String id) async {
    final record = await (_db.select(
      _db.records,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (record == null) {
      return null;
    }
    final cat = await (_db.select(
      _db.cats,
    )..where((c) => c.id.equals(record.catId))).getSingleOrNull();
    final type = await _typeName(record.recordTypeId);
    final at = record.recordedAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final time =
        '${two(at.month)}/${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
    return '$time ${cat?.name ?? '（猫なし）'}の${type ?? '（項目なし）'}';
  }

  Future<String?> _typeName(String id) async => (await (_db.select(
    _db.recordTypes,
  )..where((t) => t.id.equals(id))).getSingleOrNull())?.name;

  /// 送り直す。同期待ちに戻して、この一覧から外す。次の同期で、その時点の行の内容を送る
  Future<void> resend(String userId, RejectedChangeView change) =>
      _db.transaction(() async {
        await _db
            .into(_db.pendingChanges)
            .insert(
              PendingChangesCompanion.insert(
                userId: userId,
                targetTable: change.table,
                rowId: change.rowId,
                // おうちはおうちの作成（POST /households）で送る
                operation: change.table == 'households' ? 'create' : 'upsert',
                payload: jsonEncode({'id': change.rowId}),
              ),
            );
        await dismiss(userId, change);
      });

  /// 一覧から消す（送らない）
  Future<void> dismiss(String userId, RejectedChangeView change) =>
      (_db.delete(_db.rejectedChanges)..where(
            (r) =>
                r.userId.equals(userId) &
                r.targetTable.equals(change.table) &
                r.rowId.equals(change.rowId),
          ))
          .go();
}
