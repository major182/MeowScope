// 端末内 DB の表。列は DB 設計書（05）に合わせる
import 'package:drift/drift.dart';

/// 同期する表に共通の列（DB 設計書 2章）
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// サーバーが振る通し番号。端末では作らない
  IntColumn get serverSeq => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('HouseholdRow')
class Households extends Table with SyncColumns {
  TextColumn get name => text()();
}

/// おうちのメンバー（DB 設計書 4章）。同期で受け取り、表示名も一緒に持つ
@DataClassName('HouseholdMemberRow')
class HouseholdMembers extends Table with SyncColumns {
  TextColumn get householdId => text()();
  TextColumn get userId => text()();

  /// メンバーの表示名。サーバーの users の表から受け取る
  TextColumn get displayName => text().nullable()();
}

@DataClassName('CatRow')
class Cats extends Table with SyncColumns {
  TextColumn get householdId => text().references(Households, #id)();
  TextColumn get name => text()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get sex => text().nullable()();
  TextColumn get conditions => text().nullable()();
  TextColumn get iconPath => text().nullable()();

  /// `active` または `farewell`（お別れ）
  TextColumn get status => text().withDefault(const Constant('active'))();
}

@DataClassName('RecordTypeRow')
class RecordTypes extends Table with SyncColumns {
  TextColumn get householdId => text().references(Households, #id)();
  TextColumn get name => text()();

  /// アイコンのイラストの名前。標準の項目は種類で決まる
  TextColumn get icon => text().nullable()();

  /// 標準の8種類（RecordKind）または `custom`
  TextColumn get kind => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 非表示（独自の項目だけ）。記録のボタンと選択に出さず、過去の記録は残す
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
}

@DataClassName('RecordRow')
@TableIndex(name: 'records_cat_recorded_at', columns: {#catId, #recordedAt})
class Records extends Table with SyncColumns {
  TextColumn get catId => text().references(Cats, #id)();
  TextColumn get recordTypeId => text().references(RecordTypes, #id)();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get authorId => text().nullable()();
  TextColumn get authorName => text()();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get level => text().nullable()();
  TextColumn get detail => text().nullable()();
  TextColumn get memo => text().nullable()();
}

/// 端末の状態（端末だけの表）。ログイン中のユーザーと選んでいるおうちなどを、キーと値で持つ
@DataClassName('AppStateRow')
class AppStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 同期待ちの変更（端末だけの表）
@DataClassName('PendingChangeRow')
class PendingChanges extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();

  /// `upsert` または `delete`
  TextColumn get operation => text()();

  /// 送る内容（JSON）
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
