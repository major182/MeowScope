import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/record_kind.dart';

/// 今日の記録の一覧に出す1行
class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.recordedAt,
    required this.catName,
    required this.typeName,
  });

  final String id;
  final DateTime recordedAt;
  final String catName;
  final String typeName;
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
  Stream<List<RecordEntry>> watchDay(String householdId, DateTime day) {
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = DateTime(day.year, day.month, day.day + 1).toUtc();
    final r = _db.records;
    final c = _db.cats;
    final t = _db.recordTypes;
    final q =
        _db.select(r).join([
            innerJoin(c, c.id.equalsExp(r.catId)),
            innerJoin(t, t.id.equalsExp(r.recordTypeId)),
          ])
          ..where(
            c.householdId.equals(householdId) &
                r.deletedAt.isNull() &
                r.recordedAt.isBiggerOrEqualValue(start) &
                r.recordedAt.isSmallerThanValue(end),
          )
          ..orderBy([OrderingTerm.desc(r.recordedAt)]);
    return q.watch().map(
      (rows) => [
        for (final row in rows)
          RecordEntry(
            id: row.readTable(r).id,
            recordedAt: row.readTable(r).recordedAt.toLocal(),
            catName: row.readTable(c).name,
            typeName: row.readTable(t).name,
          ),
      ],
    );
  }
}
