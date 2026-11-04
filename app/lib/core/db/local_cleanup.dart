import 'dart:io';

import 'package:drift/drift.dart';

import '../../features/auth/data/auth_repository.dart';
import 'app_database.dart';

/// 端末から1つのおうちのデータを消す。おうちを抜けたとき（この端末でも別の端末でも）に使う（API 設計書 5章）
Future<void> removeHouseholdLocally(
  AppDatabase db,
  String userId,
  String householdId,
) async {
  final cats = db.selectOnly(db.cats)
    ..addColumns([db.cats.id])
    ..where(db.cats.householdId.equals(householdId));
  final records = db.selectOnly(db.records)
    ..addColumns([db.records.id])
    ..where(db.records.catId.isInQuery(cats));
  await (db.delete(
    db.recordPhotos,
  )..where((p) => p.recordId.isInQuery(records))).go();
  await (db.delete(db.records)..where((r) => r.catId.isInQuery(cats))).go();
  await (db.delete(
    db.cats,
  )..where((c) => c.householdId.equals(householdId))).go();
  final types = db.selectOnly(db.recordTypes)
    ..addColumns([db.recordTypes.id])
    ..where(db.recordTypes.householdId.equals(householdId));
  await (db.delete(
    db.widgetButtons,
  )..where((w) => w.recordTypeId.isInQuery(types))).go();
  await (db.delete(
    db.recordTypes,
  )..where((t) => t.householdId.equals(householdId))).go();
  await (db.delete(
    db.householdMembers,
  )..where((m) => m.householdId.equals(householdId))).go();
  await (db.delete(db.households)..where((h) => h.id.equals(householdId))).go();
  for (final key in [
    SessionKeys.householdId,
    SessionKeys.householdOf(userId),
  ]) {
    await (db.delete(
      db.appStates,
    )..where((s) => s.key.equals(key) & s.value.equals(householdId))).go();
  }
}

/// 端末の同期したデータと写真をすべて消す。端末の設定（週の始まり）は残す
///
/// ログアウト（送っていない変更がないとき）と退会で使う
Future<void> wipeLocalData(AppDatabase db) async {
  for (final photo in await db.select(db.localPhotos).get()) {
    try {
      final file = File(photo.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 消せなくても続ける
    }
  }
  await db.delete(db.localPhotos).go();
  await db.delete(db.pendingPhotos).go();
  await db.delete(db.recordPhotos).go();
  await db.delete(db.records).go();
  await db.delete(db.widgetButtons).go();
  await db.delete(db.recordTypes).go();
  await db.delete(db.cats).go();
  await db.delete(db.householdMembers).go();
  await db.delete(db.households).go();
  await (db.delete(db.appStates)..where(
        (s) =>
            s.key.like('sync.%') |
            s.key.like('household.%') |
            s.key.like('session.%'),
      ))
      .go();
}
