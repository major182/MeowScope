import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/record_kind.dart';

/// 記録の一覧（今日の記録・カレンダー・日別一覧）に出す1行
class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.recordedAt,
    required this.catName,
    required this.typeName,
    required this.catId,
    required this.kind,
    required this.hasMemo,
    required this.recordTypeId,
    this.valueNumber,
  });

  final String id;
  final DateTime recordedAt;
  final String catName;
  final String typeName;
  final String catId;

  /// 項目の種類（RecordKind の名前または custom）
  final String kind;

  /// メモがあるか
  final bool hasMemo;

  final String recordTypeId;

  /// 体重などの数値
  final double? valueNumber;
}

/// 記録の詳細の画面に出す内容
class RecordDetailView {
  const RecordDetailView({
    required this.record,
    required this.catName,
    required this.typeName,
    required this.kind,
  });

  final RecordRow record;
  final String catName;
  final String typeName;

  /// 項目の種類（RecordKind の名前または custom）
  final String kind;
}

/// 記録したユーザー
class Author {
  const Author({required this.id, required this.name});

  final String id;
  final String name;
}

/// 記録と記録項目の読み書き。書き込みは同期待ちの変更も同時に残す
class RecordRepository {
  RecordRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 標準の8項目を登録する。すでにあれば何もしない
  Future<void> addStandardTypes(String householdId) async {
    final existing = await (_db.select(
      _db.recordTypes,
    )..where((t) => t.householdId.equals(householdId))).get();
    if (existing.any((t) => t.kind != RecordKind.custom)) {
      return;
    }
    final now = _clock().toUtc();
    await _db.batch((b) {
      for (final kind in RecordKind.values) {
        b.insert(
          _db.recordTypes,
          RecordTypesCompanion.insert(
            id: _uuid.v4(),
            createdAt: now,
            updatedAt: now,
            householdId: householdId,
            name: kind.label,
            icon: Value(kind.icon),
            kind: kind.name,
            sortOrder: Value(kind.index),
          ),
        );
      }
    });
  }

  /// おうちの記録項目を並び順で見張る（削除済みを除く）
  Stream<List<RecordTypeRow>> watchTypes(String householdId) {
    final q = _db.select(_db.recordTypes)
      ..where((t) => t.householdId.equals(householdId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return q.watch();
  }

  /// 記録できる猫（お別れと削除済みを除く）を見張る
  Stream<List<CatRow>> watchActiveCats(String householdId) {
    final q = _db.select(_db.cats)
      ..where(
        (c) =>
            c.householdId.equals(householdId) &
            c.deletedAt.isNull() &
            c.status.equals('active'),
      )
      ..orderBy([(c) => OrderingTerm(expression: c.createdAt)]);
    return q.watch();
  }

  /// 詳細なしで記録を保存する（BR-01、BR-02）。保存した記録の ID を返す
  Future<String> addRecord({
    required String catId,
    required String recordTypeId,
    required Author author,
  }) {
    final id = _uuid.v4();
    final now = _clock().toUtc();
    return _db.transaction(() async {
      await _db
          .into(_db.records)
          .insert(
            RecordsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              catId: catId,
              recordTypeId: recordTypeId,
              recordedAt: now,
              authorId: Value(author.id),
              authorName: author.name,
            ),
          );
      await _db
          .into(_db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: author.id,
              targetTable: 'records',
              rowId: id,
              operation: 'upsert',
              payload: jsonEncode({
                'catId': catId,
                'recordTypeId': recordTypeId,
                'recordedAt': now.toIso8601String(),
                'authorName': author.name,
              }),
            ),
          );
      return id;
    });
  }

  /// 端末の時刻で、指定した日の記録を新しい順に見張る
  Stream<List<RecordEntry>> watchDay(String householdId, DateTime day) =>
      watchRange(
        householdId,
        from: DateTime(day.year, day.month, day.day),
        to: DateTime(day.year, day.month, day.day + 1),
        newestFirst: true,
      );

  /// 期間（from 以上 to 未満）の記録を見張る。catId を渡すとその猫だけにする
  Stream<List<RecordEntry>> watchRange(
    String householdId, {
    required DateTime from,
    required DateTime to,
    String? catId,
    bool newestFirst = false,
  }) {
    final r = _db.records;
    final c = _db.cats;
    final t = _db.recordTypes;
    var where =
        c.householdId.equals(householdId) &
        c.deletedAt.isNull() &
        r.deletedAt.isNull() &
        r.recordedAt.isBiggerOrEqualValue(from.toUtc()) &
        r.recordedAt.isSmallerThanValue(to.toUtc());
    if (catId != null) {
      where = where & r.catId.equals(catId);
    }
    final q =
        _db.select(r).join([
            innerJoin(c, c.id.equalsExp(r.catId)),
            innerJoin(t, t.id.equalsExp(r.recordTypeId)),
          ])
          ..where(where)
          ..orderBy([
            newestFirst
                ? OrderingTerm.desc(r.recordedAt)
                : OrderingTerm.asc(r.recordedAt),
          ]);
    return q.watch().map(
      (rows) => [
        for (final row in rows)
          RecordEntry(
            id: row.readTable(r).id,
            recordedAt: row.readTable(r).recordedAt.toLocal(),
            catName: row.readTable(c).name,
            typeName: row.readTable(t).name,
            catId: row.readTable(r).catId,
            kind: row.readTable(t).kind,
            hasMemo: row.readTable(r).memo != null,
            recordTypeId: row.readTable(r).recordTypeId,
            valueNumber: row.readTable(r).valueNumber,
          ),
      ],
    );
  }

  /// 絞り込みに出す猫（お別れを含み、削除済みを除く）を登録順に見張る
  Stream<List<CatRow>> watchCats(String householdId) {
    final q = _db.select(_db.cats)
      ..where((c) => c.householdId.equals(householdId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm(expression: c.createdAt)]);
    return q.watch();
  }

  /// 記録1件を、猫と項目の名前つきで見張る。削除済みや存在しなければ null
  Stream<RecordDetailView?> watchRecord(String id) {
    final r = _db.records;
    final c = _db.cats;
    final t = _db.recordTypes;
    final q = _db.select(r).join([
      innerJoin(c, c.id.equalsExp(r.catId)),
      innerJoin(t, t.id.equalsExp(r.recordTypeId)),
    ])..where(r.id.equals(id) & r.deletedAt.isNull());
    return q.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }
      final type = row.readTable(t);
      return RecordDetailView(
        record: row.readTable(r),
        catName: row.readTable(c).name,
        typeName: type.name,
        kind: type.kind,
      );
    });
  }

  /// 記録の詳細を更新する（BR-01：すべて任意）。空のメモは空として保存する
  Future<void> updateRecord({
    required String id,
    required DateTime recordedAt,
    required String? level,
    required double? valueNumber,
    required String? memo,
    required Author author,
  }) {
    final now = _clock().toUtc();
    final trimmed = memo?.trim();
    final cleanMemo = trimmed == null || trimmed.isEmpty ? null : trimmed;
    return _db.transaction(() async {
      final count =
          await (_db.update(
            _db.records,
          )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).write(
            RecordsCompanion(
              updatedAt: Value(now),
              recordedAt: Value(recordedAt.toUtc()),
              level: Value(level),
              valueNumber: Value(valueNumber),
              memo: Value(cleanMemo),
            ),
          );
      if (count == 0) {
        throw StateError('記録が見つかりません: $id');
      }
      await _addPending(author, id, 'upsert', {
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'level': level,
        'valueNumber': valueNumber,
        'memo': cleanMemo,
        'updatedAt': now.toIso8601String(),
      });
    });
  }

  /// 記録を削除する。削除の時刻を残し、更新として同期する（BR-11）
  Future<void> deleteRecord({required String id, required Author author}) {
    final now = _clock().toUtc();
    return _db.transaction(() async {
      final count =
          await (_db.update(
            _db.records,
          )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).write(
            RecordsCompanion(updatedAt: Value(now), deletedAt: Value(now)),
          );
      if (count == 0) {
        throw StateError('記録が見つかりません: $id');
      }
      await _addPending(author, id, 'delete', {
        'deletedAt': now.toIso8601String(),
      });
    });
  }

  Future<void> _addPending(
    Author author,
    String id,
    String operation,
    Map<String, Object?> payload,
  ) => _db
      .into(_db.pendingChanges)
      .insert(
        PendingChangesCompanion.insert(
          userId: author.id,
          targetTable: 'records',
          rowId: id,
          operation: operation,
          payload: jsonEncode(payload),
        ),
      );
}
