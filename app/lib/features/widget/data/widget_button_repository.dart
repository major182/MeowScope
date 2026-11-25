import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

/// ウィジェットのボタン1つ。押すと [type] を記録する
class WidgetButtonView {
  const WidgetButtonView({required this.id, required this.type});

  final String id;
  final RecordTypeRow type;
}

/// ウィジェットのボタン（S-44、F-WG-01）
///
/// ボタンはアカウントのもので、同期でサーバーに保存し、機種変更でも引き継ぐ（BR-22、AC-13）。
/// 記録項目はおうちのものなので、今のおうちの項目のボタンだけを出す
class WidgetButtonRepository {
  WidgetButtonRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 1人が1つのおうちに登録できるボタンの数（サーバーと同じ。BR-40）
  static const maxButtons = 4;

  /// 今のおうちのボタンを並び順に見張る。削除された項目のボタンは出さない。
  /// 非表示の項目のボタンも出すので、ウィジェットに出すときは呼ぶ側で除く
  Stream<List<WidgetButtonView>> watchButtons(
    String userId,
    String householdId,
  ) => _watch(userId, householdId);

  /// すべてのおうちのボタンを見張る（おうちごとのウィジェットに渡す。BR-40）。
  /// おうちは項目の [RecordTypeRow.householdId] で分ける
  Stream<List<WidgetButtonView>> watchAllButtons(String userId) =>
      _watch(userId, null);

  Stream<List<WidgetButtonView>> _watch(String userId, String? householdId) {
    final b = _db.widgetButtons;
    final t = _db.recordTypes;
    final q = _db.select(b).join([innerJoin(t, t.id.equalsExp(b.recordTypeId))])
      ..where(
        b.userId.equals(userId) &
            b.deletedAt.isNull() &
            (householdId == null
                ? const Constant(true)
                : t.householdId.equals(householdId)) &
            t.deletedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(b.sortOrder), OrderingTerm.asc(b.createdAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          WidgetButtonView(id: r.readTable(b).id, type: r.readTable(t)),
      ],
    );
  }

  /// 自分の残っているボタンのうち、[householdId] のおうちの項目のものを並び順に返す
  ///
  /// 上限と並び順（0〜3）は、おうちごとに数える（BR-40）。おうちごとにウィジェットを置くため
  Future<List<WidgetButtonRow>> _active(String userId, String householdId) {
    final types = _db.selectOnly(_db.recordTypes)
      ..addColumns([_db.recordTypes.id])
      ..where(_db.recordTypes.householdId.equals(householdId));
    return (_db.select(_db.widgetButtons)
          ..where(
            (w) =>
                w.userId.equals(userId) &
                w.deletedAt.isNull() &
                w.recordTypeId.isInQuery(types),
          )
          ..orderBy([
            (w) => OrderingTerm.asc(w.sortOrder),
            (w) => OrderingTerm.asc(w.createdAt),
          ]))
        .get();
  }

  /// 記録項目のおうち。項目がなければ [StateError]
  Future<String> _householdOfType(String recordTypeId) async {
    final type = await (_db.select(
      _db.recordTypes,
    )..where((t) => t.id.equals(recordTypeId))).getSingleOrNull();
    if (type == null) {
      throw StateError('記録項目が見つかりません: $recordTypeId');
    }
    return type.householdId;
  }

  /// ボタンを最後に足す。そのおうちで上限に達しているときと、同じ項目のボタンがあるときは [StateError]
  Future<String> add({required String userId, required String recordTypeId}) {
    return _db.transaction(() async {
      final active = await _active(
        userId,
        await _householdOfType(recordTypeId),
      );
      if (active.length >= maxButtons) {
        throw StateError('ボタンは$maxButtonsつまでです');
      }
      if (active.any((w) => w.recordTypeId == recordTypeId)) {
        throw StateError('同じ項目のボタンがあります: $recordTypeId');
      }
      final id = _uuid.v4();
      final now = _clock().toUtc();
      await _db
          .into(_db.widgetButtons)
          .insert(
            WidgetButtonsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              userId: userId,
              recordTypeId: recordTypeId,
              sortOrder: Value(active.length),
            ),
          );
      await _addPending(userId, id);
      return id;
    });
  }

  /// ボタンを削除し、残りの並び順を詰める
  Future<void> remove({required String userId, required String id}) {
    return _db.transaction(() async {
      final now = _clock().toUtc();
      final count =
          await (_db.update(_db.widgetButtons)..where(
                (w) =>
                    w.id.equals(id) &
                    w.userId.equals(userId) &
                    w.deletedAt.isNull(),
              ))
              .write(
                WidgetButtonsCompanion(
                  updatedAt: Value(now),
                  deletedAt: Value(now),
                ),
              );
      if (count == 0) {
        throw StateError('ボタンが見つかりません: $id');
      }
      await _addPending(userId, id);
      // 消したボタンと同じおうちのボタンだけを詰める
      final removed = await (_db.select(
        _db.widgetButtons,
      )..where((w) => w.id.equals(id))).getSingle();
      final householdId = await _householdOfType(removed.recordTypeId);
      await _renumber(userId, householdId, [
        for (final w in await _active(userId, householdId)) w.id,
      ]);
    });
  }

  /// [householdId] のおうちのボタンを並べ替える。[orderedIds] は画面に出ている順。
  /// 出ていないボタン（同じおうちで、画面に出ていないもの）は後ろに回す。ほかのおうちのボタンは変えない
  Future<void> reorder({
    required String userId,
    required String householdId,
    required List<String> orderedIds,
  }) {
    return _db.transaction(() async {
      final others = [
        for (final w in await _active(userId, householdId))
          if (!orderedIds.contains(w.id)) w.id,
      ];
      await _renumber(userId, householdId, [...orderedIds, ...others]);
    });
  }

  /// [householdId] のおうちのボタンの並び順を 0 から振り直す。変わった行だけを同期に回す
  Future<void> _renumber(
    String userId,
    String householdId,
    List<String> ids,
  ) async {
    final current = {
      for (final w in await _active(userId, householdId)) w.id: w.sortOrder,
    };
    final now = _clock().toUtc();
    for (final (i, id) in ids.indexed) {
      if (!current.containsKey(id) || current[id] == i) {
        continue;
      }
      await (_db.update(
        _db.widgetButtons,
      )..where((w) => w.id.equals(id))).write(
        WidgetButtonsCompanion(updatedAt: Value(now), sortOrder: Value(i)),
      );
      await _addPending(userId, id);
    }
  }

  /// 同期待ちに積む。送る内容は送るときの行から作る（API 設計書 5章）
  Future<void> _addPending(String userId, String id) => _db
      .into(_db.pendingChanges)
      .insert(
        PendingChangesCompanion.insert(
          userId: userId,
          targetTable: 'widget_buttons',
          rowId: id,
          operation: 'upsert',
          payload: jsonEncode({'id': id}),
        ),
      );
}
