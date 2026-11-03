// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HouseholdsTable extends Households
    with TableInfo<$HouseholdsTable, HouseholdRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'households';
  @override
  VerificationContext validateIntegrity(
    Insertable<HouseholdRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HouseholdRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseholdRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $HouseholdsTable createAlias(String alias) {
    return $HouseholdsTable(attachedDatabase, alias);
  }
}

class HouseholdRow extends DataClass implements Insertable<HouseholdRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String name;
  const HouseholdRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['name'] = Variable<String>(name);
    return map;
  }

  HouseholdsCompanion toCompanion(bool nullToAbsent) {
    return HouseholdsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      name: Value(name),
    );
  }

  factory HouseholdRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseholdRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'name': serializer.toJson<String>(name),
    };
  }

  HouseholdRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? name,
  }) => HouseholdRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    name: name ?? this.name,
  );
  HouseholdRow copyWithCompanion(HouseholdsCompanion data) {
    return HouseholdRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, deletedAt, serverSeq, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseholdRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.name == this.name);
}

class HouseholdsCompanion extends UpdateCompanion<HouseholdRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> name;
  final Value<int> rowid;
  const HouseholdsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name);
  static Insertable<HouseholdRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return HouseholdsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HouseholdMembersTable extends HouseholdMembers
    with TableInfo<$HouseholdMembersTable, HouseholdMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    userId,
    displayName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'household_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<HouseholdMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HouseholdMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseholdMemberRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
    );
  }

  @override
  $HouseholdMembersTable createAlias(String alias) {
    return $HouseholdMembersTable(attachedDatabase, alias);
  }
}

class HouseholdMemberRow extends DataClass
    implements Insertable<HouseholdMemberRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String householdId;
  final String userId;

  /// メンバーの表示名。サーバーの users の表から受け取る
  final String? displayName;
  const HouseholdMemberRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.householdId,
    required this.userId,
    this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['household_id'] = Variable<String>(householdId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    return map;
  }

  HouseholdMembersCompanion toCompanion(bool nullToAbsent) {
    return HouseholdMembersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      householdId: Value(householdId),
      userId: Value(userId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
    );
  }

  factory HouseholdMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseholdMemberRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      householdId: serializer.fromJson<String>(json['householdId']),
      userId: serializer.fromJson<String>(json['userId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'householdId': serializer.toJson<String>(householdId),
      'userId': serializer.toJson<String>(userId),
      'displayName': serializer.toJson<String?>(displayName),
    };
  }

  HouseholdMemberRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? householdId,
    String? userId,
    Value<String?> displayName = const Value.absent(),
  }) => HouseholdMemberRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    householdId: householdId ?? this.householdId,
    userId: userId ?? this.userId,
    displayName: displayName.present ? displayName.value : this.displayName,
  );
  HouseholdMemberRow copyWithCompanion(HouseholdMembersCompanion data) {
    return HouseholdMemberRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      userId: data.userId.present ? data.userId.value : this.userId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMemberRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    userId,
    displayName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseholdMemberRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.householdId == this.householdId &&
          other.userId == this.userId &&
          other.displayName == this.displayName);
}

class HouseholdMembersCompanion extends UpdateCompanion<HouseholdMemberRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> householdId;
  final Value<String> userId;
  final Value<String?> displayName;
  final Value<int> rowid;
  const HouseholdMembersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.householdId = const Value.absent(),
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdMembersCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String householdId,
    required String userId,
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       householdId = Value(householdId),
       userId = Value(userId);
  static Insertable<HouseholdMemberRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? householdId,
    Expression<String>? userId,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (householdId != null) 'household_id': householdId,
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdMembersCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? householdId,
    Value<String>? userId,
    Value<String?>? displayName,
    Value<int>? rowid,
  }) {
    return HouseholdMembersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMembersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatsTable extends Cats with TableInfo<$CatsTable, CatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES households (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conditionsMeta = const VerificationMeta(
    'conditions',
  );
  @override
  late final GeneratedColumn<String> conditions = GeneratedColumn<String>(
    'conditions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconPathMeta = const VerificationMeta(
    'iconPath',
  );
  @override
  late final GeneratedColumn<String> iconPath = GeneratedColumn<String>(
    'icon_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    name,
    birthDate,
    sex,
    conditions,
    iconPath,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cats';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('conditions')) {
      context.handle(
        _conditionsMeta,
        conditions.isAcceptableOrUnknown(data['conditions']!, _conditionsMeta),
      );
    }
    if (data.containsKey('icon_path')) {
      context.handle(
        _iconPathMeta,
        iconPath.isAcceptableOrUnknown(data['icon_path']!, _iconPathMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      ),
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      conditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions'],
      ),
      iconPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_path'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $CatsTable createAlias(String alias) {
    return $CatsTable(attachedDatabase, alias);
  }
}

class CatRow extends DataClass implements Insertable<CatRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String householdId;
  final String name;
  final DateTime? birthDate;
  final String? sex;
  final String? conditions;
  final String? iconPath;

  /// `active` または `farewell`（お別れ）
  final String status;
  const CatRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.householdId,
    required this.name,
    this.birthDate,
    this.sex,
    this.conditions,
    this.iconPath,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['household_id'] = Variable<String>(householdId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<DateTime>(birthDate);
    }
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || conditions != null) {
      map['conditions'] = Variable<String>(conditions);
    }
    if (!nullToAbsent || iconPath != null) {
      map['icon_path'] = Variable<String>(iconPath);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  CatsCompanion toCompanion(bool nullToAbsent) {
    return CatsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      householdId: Value(householdId),
      name: Value(name),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      conditions: conditions == null && nullToAbsent
          ? const Value.absent()
          : Value(conditions),
      iconPath: iconPath == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPath),
      status: Value(status),
    );
  }

  factory CatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      householdId: serializer.fromJson<String>(json['householdId']),
      name: serializer.fromJson<String>(json['name']),
      birthDate: serializer.fromJson<DateTime?>(json['birthDate']),
      sex: serializer.fromJson<String?>(json['sex']),
      conditions: serializer.fromJson<String?>(json['conditions']),
      iconPath: serializer.fromJson<String?>(json['iconPath']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'householdId': serializer.toJson<String>(householdId),
      'name': serializer.toJson<String>(name),
      'birthDate': serializer.toJson<DateTime?>(birthDate),
      'sex': serializer.toJson<String?>(sex),
      'conditions': serializer.toJson<String?>(conditions),
      'iconPath': serializer.toJson<String?>(iconPath),
      'status': serializer.toJson<String>(status),
    };
  }

  CatRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? householdId,
    String? name,
    Value<DateTime?> birthDate = const Value.absent(),
    Value<String?> sex = const Value.absent(),
    Value<String?> conditions = const Value.absent(),
    Value<String?> iconPath = const Value.absent(),
    String? status,
  }) => CatRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    householdId: householdId ?? this.householdId,
    name: name ?? this.name,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    sex: sex.present ? sex.value : this.sex,
    conditions: conditions.present ? conditions.value : this.conditions,
    iconPath: iconPath.present ? iconPath.value : this.iconPath,
    status: status ?? this.status,
  );
  CatRow copyWithCompanion(CatsCompanion data) {
    return CatRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      name: data.name.present ? data.name.value : this.name,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      sex: data.sex.present ? data.sex.value : this.sex,
      conditions: data.conditions.present
          ? data.conditions.value
          : this.conditions,
      iconPath: data.iconPath.present ? data.iconPath.value : this.iconPath,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('sex: $sex, ')
          ..write('conditions: $conditions, ')
          ..write('iconPath: $iconPath, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    name,
    birthDate,
    sex,
    conditions,
    iconPath,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.householdId == this.householdId &&
          other.name == this.name &&
          other.birthDate == this.birthDate &&
          other.sex == this.sex &&
          other.conditions == this.conditions &&
          other.iconPath == this.iconPath &&
          other.status == this.status);
}

class CatsCompanion extends UpdateCompanion<CatRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> householdId;
  final Value<String> name;
  final Value<DateTime?> birthDate;
  final Value<String?> sex;
  final Value<String?> conditions;
  final Value<String?> iconPath;
  final Value<String> status;
  final Value<int> rowid;
  const CatsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.householdId = const Value.absent(),
    this.name = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.sex = const Value.absent(),
    this.conditions = const Value.absent(),
    this.iconPath = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String householdId,
    required String name,
    this.birthDate = const Value.absent(),
    this.sex = const Value.absent(),
    this.conditions = const Value.absent(),
    this.iconPath = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       householdId = Value(householdId),
       name = Value(name);
  static Insertable<CatRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? householdId,
    Expression<String>? name,
    Expression<DateTime>? birthDate,
    Expression<String>? sex,
    Expression<String>? conditions,
    Expression<String>? iconPath,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (householdId != null) 'household_id': householdId,
      if (name != null) 'name': name,
      if (birthDate != null) 'birth_date': birthDate,
      if (sex != null) 'sex': sex,
      if (conditions != null) 'conditions': conditions,
      if (iconPath != null) 'icon_path': iconPath,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? householdId,
    Value<String>? name,
    Value<DateTime?>? birthDate,
    Value<String?>? sex,
    Value<String?>? conditions,
    Value<String?>? iconPath,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return CatsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      conditions: conditions ?? this.conditions,
      iconPath: iconPath ?? this.iconPath,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (conditions.present) {
      map['conditions'] = Variable<String>(conditions.value);
    }
    if (iconPath.present) {
      map['icon_path'] = Variable<String>(iconPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('sex: $sex, ')
          ..write('conditions: $conditions, ')
          ..write('iconPath: $iconPath, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordTypesTable extends RecordTypes
    with TableInfo<$RecordTypesTable, RecordTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES households (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    name,
    icon,
    kind,
    sortOrder,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordTypeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordTypeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $RecordTypesTable createAlias(String alias) {
    return $RecordTypesTable(attachedDatabase, alias);
  }
}

class RecordTypeRow extends DataClass implements Insertable<RecordTypeRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String householdId;
  final String name;

  /// アイコンのイラストの名前。標準の項目は種類で決まる
  final String? icon;

  /// 標準の8種類（RecordKind）または `custom`
  final String kind;
  final int sortOrder;

  /// 非表示（独自の項目だけ）。記録のボタンと選択に出さず、過去の記録は残す
  final bool hidden;
  const RecordTypeRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.householdId,
    required this.name,
    this.icon,
    required this.kind,
    required this.sortOrder,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['household_id'] = Variable<String>(householdId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['kind'] = Variable<String>(kind);
    map['sort_order'] = Variable<int>(sortOrder);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  RecordTypesCompanion toCompanion(bool nullToAbsent) {
    return RecordTypesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      householdId: Value(householdId),
      name: Value(name),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      hidden: Value(hidden),
    );
  }

  factory RecordTypeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordTypeRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      householdId: serializer.fromJson<String>(json['householdId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String?>(json['icon']),
      kind: serializer.fromJson<String>(json['kind']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'householdId': serializer.toJson<String>(householdId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String?>(icon),
      'kind': serializer.toJson<String>(kind),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  RecordTypeRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? householdId,
    String? name,
    Value<String?> icon = const Value.absent(),
    String? kind,
    int? sortOrder,
    bool? hidden,
  }) => RecordTypeRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    householdId: householdId ?? this.householdId,
    name: name ?? this.name,
    icon: icon.present ? icon.value : this.icon,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    hidden: hidden ?? this.hidden,
  );
  RecordTypeRow copyWithCompanion(RecordTypesCompanion data) {
    return RecordTypeRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordTypeRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    householdId,
    name,
    icon,
    kind,
    sortOrder,
    hidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordTypeRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.householdId == this.householdId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.hidden == this.hidden);
}

class RecordTypesCompanion extends UpdateCompanion<RecordTypeRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> householdId;
  final Value<String> name;
  final Value<String?> icon;
  final Value<String> kind;
  final Value<int> sortOrder;
  final Value<bool> hidden;
  final Value<int> rowid;
  const RecordTypesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.householdId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordTypesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String householdId,
    required String name,
    this.icon = const Value.absent(),
    required String kind,
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       householdId = Value(householdId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<RecordTypeRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? householdId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (householdId != null) 'household_id': householdId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordTypesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? householdId,
    Value<String>? name,
    Value<String?>? icon,
    Value<String>? kind,
    Value<int>? sortOrder,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return RecordTypesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordTypesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catIdMeta = const VerificationMeta('catId');
  @override
  late final GeneratedColumn<String> catId = GeneratedColumn<String>(
    'cat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cats (id)',
    ),
  );
  static const VerificationMeta _recordTypeIdMeta = const VerificationMeta(
    'recordTypeId',
  );
  @override
  late final GeneratedColumn<String> recordTypeId = GeneratedColumn<String>(
    'record_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES record_types (id)',
    ),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorNameMeta = const VerificationMeta(
    'authorName',
  );
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
    'author_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueNumberMeta = const VerificationMeta(
    'valueNumber',
  );
  @override
  late final GeneratedColumn<double> valueNumber = GeneratedColumn<double>(
    'value_number',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    catId,
    recordTypeId,
    recordedAt,
    authorId,
    authorName,
    valueNumber,
    level,
    detail,
    memo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('cat_id')) {
      context.handle(
        _catIdMeta,
        catId.isAcceptableOrUnknown(data['cat_id']!, _catIdMeta),
      );
    } else if (isInserting) {
      context.missing(_catIdMeta);
    }
    if (data.containsKey('record_type_id')) {
      context.handle(
        _recordTypeIdMeta,
        recordTypeId.isAcceptableOrUnknown(
          data['record_type_id']!,
          _recordTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordTypeIdMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('author_name')) {
      context.handle(
        _authorNameMeta,
        authorName.isAcceptableOrUnknown(data['author_name']!, _authorNameMeta),
      );
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('value_number')) {
      context.handle(
        _valueNumberMeta,
        valueNumber.isAcceptableOrUnknown(
          data['value_number']!,
          _valueNumberMeta,
        ),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      catId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cat_id'],
      )!,
      recordTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type_id'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      authorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_name'],
      )!,
      valueNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value_number'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String catId;
  final String recordTypeId;
  final DateTime recordedAt;
  final String? authorId;
  final String authorName;
  final double? valueNumber;
  final String? level;
  final String? detail;
  final String? memo;
  const RecordRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.catId,
    required this.recordTypeId,
    required this.recordedAt,
    this.authorId,
    required this.authorName,
    this.valueNumber,
    this.level,
    this.detail,
    this.memo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['cat_id'] = Variable<String>(catId);
    map['record_type_id'] = Variable<String>(recordTypeId);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['author_name'] = Variable<String>(authorName);
    if (!nullToAbsent || valueNumber != null) {
      map['value_number'] = Variable<double>(valueNumber);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<String>(level);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      catId: Value(catId),
      recordTypeId: Value(recordTypeId),
      recordedAt: Value(recordedAt),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      authorName: Value(authorName),
      valueNumber: valueNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(valueNumber),
      level: level == null && nullToAbsent
          ? const Value.absent()
          : Value(level),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      catId: serializer.fromJson<String>(json['catId']),
      recordTypeId: serializer.fromJson<String>(json['recordTypeId']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      authorName: serializer.fromJson<String>(json['authorName']),
      valueNumber: serializer.fromJson<double?>(json['valueNumber']),
      level: serializer.fromJson<String?>(json['level']),
      detail: serializer.fromJson<String?>(json['detail']),
      memo: serializer.fromJson<String?>(json['memo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'catId': serializer.toJson<String>(catId),
      'recordTypeId': serializer.toJson<String>(recordTypeId),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'authorId': serializer.toJson<String?>(authorId),
      'authorName': serializer.toJson<String>(authorName),
      'valueNumber': serializer.toJson<double?>(valueNumber),
      'level': serializer.toJson<String?>(level),
      'detail': serializer.toJson<String?>(detail),
      'memo': serializer.toJson<String?>(memo),
    };
  }

  RecordRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? catId,
    String? recordTypeId,
    DateTime? recordedAt,
    Value<String?> authorId = const Value.absent(),
    String? authorName,
    Value<double?> valueNumber = const Value.absent(),
    Value<String?> level = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    Value<String?> memo = const Value.absent(),
  }) => RecordRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    catId: catId ?? this.catId,
    recordTypeId: recordTypeId ?? this.recordTypeId,
    recordedAt: recordedAt ?? this.recordedAt,
    authorId: authorId.present ? authorId.value : this.authorId,
    authorName: authorName ?? this.authorName,
    valueNumber: valueNumber.present ? valueNumber.value : this.valueNumber,
    level: level.present ? level.value : this.level,
    detail: detail.present ? detail.value : this.detail,
    memo: memo.present ? memo.value : this.memo,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      catId: data.catId.present ? data.catId.value : this.catId,
      recordTypeId: data.recordTypeId.present
          ? data.recordTypeId.value
          : this.recordTypeId,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      authorName: data.authorName.present
          ? data.authorName.value
          : this.authorName,
      valueNumber: data.valueNumber.present
          ? data.valueNumber.value
          : this.valueNumber,
      level: data.level.present ? data.level.value : this.level,
      detail: data.detail.present ? data.detail.value : this.detail,
      memo: data.memo.present ? data.memo.value : this.memo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('catId: $catId, ')
          ..write('recordTypeId: $recordTypeId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('authorId: $authorId, ')
          ..write('authorName: $authorName, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('level: $level, ')
          ..write('detail: $detail, ')
          ..write('memo: $memo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    catId,
    recordTypeId,
    recordedAt,
    authorId,
    authorName,
    valueNumber,
    level,
    detail,
    memo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.catId == this.catId &&
          other.recordTypeId == this.recordTypeId &&
          other.recordedAt == this.recordedAt &&
          other.authorId == this.authorId &&
          other.authorName == this.authorName &&
          other.valueNumber == this.valueNumber &&
          other.level == this.level &&
          other.detail == this.detail &&
          other.memo == this.memo);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> catId;
  final Value<String> recordTypeId;
  final Value<DateTime> recordedAt;
  final Value<String?> authorId;
  final Value<String> authorName;
  final Value<double?> valueNumber;
  final Value<String?> level;
  final Value<String?> detail;
  final Value<String?> memo;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.catId = const Value.absent(),
    this.recordTypeId = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.authorId = const Value.absent(),
    this.authorName = const Value.absent(),
    this.valueNumber = const Value.absent(),
    this.level = const Value.absent(),
    this.detail = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String catId,
    required String recordTypeId,
    required DateTime recordedAt,
    this.authorId = const Value.absent(),
    required String authorName,
    this.valueNumber = const Value.absent(),
    this.level = const Value.absent(),
    this.detail = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       catId = Value(catId),
       recordTypeId = Value(recordTypeId),
       recordedAt = Value(recordedAt),
       authorName = Value(authorName);
  static Insertable<RecordRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? catId,
    Expression<String>? recordTypeId,
    Expression<DateTime>? recordedAt,
    Expression<String>? authorId,
    Expression<String>? authorName,
    Expression<double>? valueNumber,
    Expression<String>? level,
    Expression<String>? detail,
    Expression<String>? memo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (catId != null) 'cat_id': catId,
      if (recordTypeId != null) 'record_type_id': recordTypeId,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (authorId != null) 'author_id': authorId,
      if (authorName != null) 'author_name': authorName,
      if (valueNumber != null) 'value_number': valueNumber,
      if (level != null) 'level': level,
      if (detail != null) 'detail': detail,
      if (memo != null) 'memo': memo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? catId,
    Value<String>? recordTypeId,
    Value<DateTime>? recordedAt,
    Value<String?>? authorId,
    Value<String>? authorName,
    Value<double?>? valueNumber,
    Value<String?>? level,
    Value<String?>? detail,
    Value<String?>? memo,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      catId: catId ?? this.catId,
      recordTypeId: recordTypeId ?? this.recordTypeId,
      recordedAt: recordedAt ?? this.recordedAt,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      valueNumber: valueNumber ?? this.valueNumber,
      level: level ?? this.level,
      detail: detail ?? this.detail,
      memo: memo ?? this.memo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (catId.present) {
      map['cat_id'] = Variable<String>(catId.value);
    }
    if (recordTypeId.present) {
      map['record_type_id'] = Variable<String>(recordTypeId.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (valueNumber.present) {
      map['value_number'] = Variable<double>(valueNumber.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('catId: $catId, ')
          ..write('recordTypeId: $recordTypeId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('authorId: $authorId, ')
          ..write('authorName: $authorName, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('level: $level, ')
          ..write('detail: $detail, ')
          ..write('memo: $memo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordPhotosTable extends RecordPhotos
    with TableInfo<$RecordPhotosTable, RecordPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES records (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedMeta = const VerificationMeta(
    'uploaded',
  );
  @override
  late final GeneratedColumn<bool> uploaded = GeneratedColumn<bool>(
    'uploaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uploaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    recordId,
    sortOrder,
    sizeBytes,
    uploaded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('uploaded')) {
      context.handle(
        _uploadedMeta,
        uploaded.isAcceptableOrUnknown(data['uploaded']!, _uploadedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordPhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      uploaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uploaded'],
      )!,
    );
  }

  @override
  $RecordPhotosTable createAlias(String alias) {
    return $RecordPhotosTable(attachedDatabase, alias);
  }
}

class RecordPhotoRow extends DataClass implements Insertable<RecordPhotoRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// サーバーが振る通し番号。端末では作らない
  final int? serverSeq;
  final String recordId;

  /// 何枚目か（1〜3）
  final int sortOrder;
  final int? sizeBytes;

  /// サーバーへ画像が送られたか。相手の端末は、送られた写真だけを取りに行く
  final bool uploaded;
  const RecordPhotoRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverSeq,
    required this.recordId,
    required this.sortOrder,
    this.sizeBytes,
    required this.uploaded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['record_id'] = Variable<String>(recordId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['uploaded'] = Variable<bool>(uploaded);
    return map;
  }

  RecordPhotosCompanion toCompanion(bool nullToAbsent) {
    return RecordPhotosCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      recordId: Value(recordId),
      sortOrder: Value(sortOrder),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      uploaded: Value(uploaded),
    );
  }

  factory RecordPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordPhotoRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      recordId: serializer.fromJson<String>(json['recordId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      uploaded: serializer.fromJson<bool>(json['uploaded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'recordId': serializer.toJson<String>(recordId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'uploaded': serializer.toJson<bool>(uploaded),
    };
  }

  RecordPhotoRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
    String? recordId,
    int? sortOrder,
    Value<int?> sizeBytes = const Value.absent(),
    bool? uploaded,
  }) => RecordPhotoRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    recordId: recordId ?? this.recordId,
    sortOrder: sortOrder ?? this.sortOrder,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    uploaded: uploaded ?? this.uploaded,
  );
  RecordPhotoRow copyWithCompanion(RecordPhotosCompanion data) {
    return RecordPhotoRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      uploaded: data.uploaded.present ? data.uploaded.value : this.uploaded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordPhotoRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('recordId: $recordId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('uploaded: $uploaded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    serverSeq,
    recordId,
    sortOrder,
    sizeBytes,
    uploaded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordPhotoRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverSeq == this.serverSeq &&
          other.recordId == this.recordId &&
          other.sortOrder == this.sortOrder &&
          other.sizeBytes == this.sizeBytes &&
          other.uploaded == this.uploaded);
}

class RecordPhotosCompanion extends UpdateCompanion<RecordPhotoRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> serverSeq;
  final Value<String> recordId;
  final Value<int> sortOrder;
  final Value<int?> sizeBytes;
  final Value<bool> uploaded;
  final Value<int> rowid;
  const RecordPhotosCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.recordId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordPhotosCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required String recordId,
    required int sortOrder,
    this.sizeBytes = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       recordId = Value(recordId),
       sortOrder = Value(sortOrder);
  static Insertable<RecordPhotoRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverSeq,
    Expression<String>? recordId,
    Expression<int>? sortOrder,
    Expression<int>? sizeBytes,
    Expression<bool>? uploaded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (recordId != null) 'record_id': recordId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (uploaded != null) 'uploaded': uploaded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordPhotosCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? serverSeq,
    Value<String>? recordId,
    Value<int>? sortOrder,
    Value<int?>? sizeBytes,
    Value<bool>? uploaded,
    Value<int>? rowid,
  }) {
    return RecordPhotosCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverSeq: serverSeq ?? this.serverSeq,
      recordId: recordId ?? this.recordId,
      sortOrder: sortOrder ?? this.sortOrder,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploaded: uploaded ?? this.uploaded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (uploaded.present) {
      map['uploaded'] = Variable<bool>(uploaded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordPhotosCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('recordId: $recordId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('uploaded: $uploaded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStatesTable extends AppStates
    with TableInfo<$AppStatesTable, AppStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppStatesTable createAlias(String alias) {
    return $AppStatesTable(attachedDatabase, alias);
  }
}

class AppStateRow extends DataClass implements Insertable<AppStateRow> {
  final String key;
  final String value;
  const AppStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStatesCompanion toCompanion(bool nullToAbsent) {
    return AppStatesCompanion(key: Value(key), value: Value(value));
  }

  factory AppStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppStateRow copyWith({String? key, String? value}) =>
      AppStateRow(key: key ?? this.key, value: value ?? this.value);
  AppStateRow copyWithCompanion(AppStatesCompanion data) {
    return AppStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppStatesCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingChangesTable extends PendingChanges
    with TableInfo<$PendingChangesTable, PendingChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    userId,
    targetTable,
    rowId,
    operation,
    payload,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PendingChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingChangeRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $PendingChangesTable createAlias(String alias) {
    return $PendingChangesTable(attachedDatabase, alias);
  }
}

class PendingChangeRow extends DataClass
    implements Insertable<PendingChangeRow> {
  final int seq;
  final String userId;
  final String targetTable;
  final String rowId;

  /// `upsert` または `delete`
  final String operation;

  /// 送る内容（JSON）
  final String payload;
  final int attempts;
  const PendingChangeRow({
    required this.seq,
    required this.userId,
    required this.targetTable,
    required this.rowId,
    required this.operation,
    required this.payload,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['user_id'] = Variable<String>(userId);
    map['target_table'] = Variable<String>(targetTable);
    map['row_id'] = Variable<String>(rowId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingChangesCompanion toCompanion(bool nullToAbsent) {
    return PendingChangesCompanion(
      seq: Value(seq),
      userId: Value(userId),
      targetTable: Value(targetTable),
      rowId: Value(rowId),
      operation: Value(operation),
      payload: Value(payload),
      attempts: Value(attempts),
    );
  }

  factory PendingChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingChangeRow(
      seq: serializer.fromJson<int>(json['seq']),
      userId: serializer.fromJson<String>(json['userId']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'userId': serializer.toJson<String>(userId),
      'targetTable': serializer.toJson<String>(targetTable),
      'rowId': serializer.toJson<String>(rowId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingChangeRow copyWith({
    int? seq,
    String? userId,
    String? targetTable,
    String? rowId,
    String? operation,
    String? payload,
    int? attempts,
  }) => PendingChangeRow(
    seq: seq ?? this.seq,
    userId: userId ?? this.userId,
    targetTable: targetTable ?? this.targetTable,
    rowId: rowId ?? this.rowId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
  );
  PendingChangeRow copyWithCompanion(PendingChangesCompanion data) {
    return PendingChangeRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      userId: data.userId.present ? data.userId.value : this.userId,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingChangeRow(')
          ..write('seq: $seq, ')
          ..write('userId: $userId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    userId,
    targetTable,
    rowId,
    operation,
    payload,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingChangeRow &&
          other.seq == this.seq &&
          other.userId == this.userId &&
          other.targetTable == this.targetTable &&
          other.rowId == this.rowId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.attempts == this.attempts);
}

class PendingChangesCompanion extends UpdateCompanion<PendingChangeRow> {
  final Value<int> seq;
  final Value<String> userId;
  final Value<String> targetTable;
  final Value<String> rowId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int> attempts;
  const PendingChangesCompanion({
    this.seq = const Value.absent(),
    this.userId = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  PendingChangesCompanion.insert({
    this.seq = const Value.absent(),
    required String userId,
    required String targetTable,
    required String rowId,
    required String operation,
    required String payload,
    this.attempts = const Value.absent(),
  }) : userId = Value(userId),
       targetTable = Value(targetTable),
       rowId = Value(rowId),
       operation = Value(operation),
       payload = Value(payload);
  static Insertable<PendingChangeRow> custom({
    Expression<int>? seq,
    Expression<String>? userId,
    Expression<String>? targetTable,
    Expression<String>? rowId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (userId != null) 'user_id': userId,
      if (targetTable != null) 'target_table': targetTable,
      if (rowId != null) 'row_id': rowId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
    });
  }

  PendingChangesCompanion copyWith({
    Value<int>? seq,
    Value<String>? userId,
    Value<String>? targetTable,
    Value<String>? rowId,
    Value<String>? operation,
    Value<String>? payload,
    Value<int>? attempts,
  }) {
    return PendingChangesCompanion(
      seq: seq ?? this.seq,
      userId: userId ?? this.userId,
      targetTable: targetTable ?? this.targetTable,
      rowId: rowId ?? this.rowId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingChangesCompanion(')
          ..write('seq: $seq, ')
          ..write('userId: $userId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $PendingPhotosTable extends PendingPhotos
    with TableInfo<$PendingPhotosTable, PendingPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<String> photoId = GeneratedColumn<String>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [photoId, userId, localPath];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {photoId};
  @override
  PendingPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPhotoRow(
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
    );
  }

  @override
  $PendingPhotosTable createAlias(String alias) {
    return $PendingPhotosTable(attachedDatabase, alias);
  }
}

class PendingPhotoRow extends DataClass implements Insertable<PendingPhotoRow> {
  final String photoId;
  final String userId;
  final String localPath;
  const PendingPhotoRow({
    required this.photoId,
    required this.userId,
    required this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['photo_id'] = Variable<String>(photoId);
    map['user_id'] = Variable<String>(userId);
    map['local_path'] = Variable<String>(localPath);
    return map;
  }

  PendingPhotosCompanion toCompanion(bool nullToAbsent) {
    return PendingPhotosCompanion(
      photoId: Value(photoId),
      userId: Value(userId),
      localPath: Value(localPath),
    );
  }

  factory PendingPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPhotoRow(
      photoId: serializer.fromJson<String>(json['photoId']),
      userId: serializer.fromJson<String>(json['userId']),
      localPath: serializer.fromJson<String>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'photoId': serializer.toJson<String>(photoId),
      'userId': serializer.toJson<String>(userId),
      'localPath': serializer.toJson<String>(localPath),
    };
  }

  PendingPhotoRow copyWith({
    String? photoId,
    String? userId,
    String? localPath,
  }) => PendingPhotoRow(
    photoId: photoId ?? this.photoId,
    userId: userId ?? this.userId,
    localPath: localPath ?? this.localPath,
  );
  PendingPhotoRow copyWithCompanion(PendingPhotosCompanion data) {
    return PendingPhotoRow(
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      userId: data.userId.present ? data.userId.value : this.userId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhotoRow(')
          ..write('photoId: $photoId, ')
          ..write('userId: $userId, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(photoId, userId, localPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPhotoRow &&
          other.photoId == this.photoId &&
          other.userId == this.userId &&
          other.localPath == this.localPath);
}

class PendingPhotosCompanion extends UpdateCompanion<PendingPhotoRow> {
  final Value<String> photoId;
  final Value<String> userId;
  final Value<String> localPath;
  final Value<int> rowid;
  const PendingPhotosCompanion({
    this.photoId = const Value.absent(),
    this.userId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPhotosCompanion.insert({
    required String photoId,
    required String userId,
    required String localPath,
    this.rowid = const Value.absent(),
  }) : photoId = Value(photoId),
       userId = Value(userId),
       localPath = Value(localPath);
  static Insertable<PendingPhotoRow> custom({
    Expression<String>? photoId,
    Expression<String>? userId,
    Expression<String>? localPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (photoId != null) 'photo_id': photoId,
      if (userId != null) 'user_id': userId,
      if (localPath != null) 'local_path': localPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPhotosCompanion copyWith({
    Value<String>? photoId,
    Value<String>? userId,
    Value<String>? localPath,
    Value<int>? rowid,
  }) {
    return PendingPhotosCompanion(
      photoId: photoId ?? this.photoId,
      userId: userId ?? this.userId,
      localPath: localPath ?? this.localPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (photoId.present) {
      map['photo_id'] = Variable<String>(photoId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhotosCompanion(')
          ..write('photoId: $photoId, ')
          ..write('userId: $userId, ')
          ..write('localPath: $localPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPhotosTable extends LocalPhotos
    with TableInfo<$LocalPhotosTable, LocalPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<String> photoId = GeneratedColumn<String>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [photoId, localPath, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {photoId};
  @override
  LocalPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPhotoRow(
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $LocalPhotosTable createAlias(String alias) {
    return $LocalPhotosTable(attachedDatabase, alias);
  }
}

class LocalPhotoRow extends DataClass implements Insertable<LocalPhotoRow> {
  final String photoId;
  final String localPath;
  final DateTime savedAt;
  const LocalPhotoRow({
    required this.photoId,
    required this.localPath,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['photo_id'] = Variable<String>(photoId);
    map['local_path'] = Variable<String>(localPath);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  LocalPhotosCompanion toCompanion(bool nullToAbsent) {
    return LocalPhotosCompanion(
      photoId: Value(photoId),
      localPath: Value(localPath),
      savedAt: Value(savedAt),
    );
  }

  factory LocalPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPhotoRow(
      photoId: serializer.fromJson<String>(json['photoId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'photoId': serializer.toJson<String>(photoId),
      'localPath': serializer.toJson<String>(localPath),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  LocalPhotoRow copyWith({
    String? photoId,
    String? localPath,
    DateTime? savedAt,
  }) => LocalPhotoRow(
    photoId: photoId ?? this.photoId,
    localPath: localPath ?? this.localPath,
    savedAt: savedAt ?? this.savedAt,
  );
  LocalPhotoRow copyWithCompanion(LocalPhotosCompanion data) {
    return LocalPhotoRow(
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPhotoRow(')
          ..write('photoId: $photoId, ')
          ..write('localPath: $localPath, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(photoId, localPath, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPhotoRow &&
          other.photoId == this.photoId &&
          other.localPath == this.localPath &&
          other.savedAt == this.savedAt);
}

class LocalPhotosCompanion extends UpdateCompanion<LocalPhotoRow> {
  final Value<String> photoId;
  final Value<String> localPath;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const LocalPhotosCompanion({
    this.photoId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPhotosCompanion.insert({
    required String photoId,
    required String localPath,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : photoId = Value(photoId),
       localPath = Value(localPath),
       savedAt = Value(savedAt);
  static Insertable<LocalPhotoRow> custom({
    Expression<String>? photoId,
    Expression<String>? localPath,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (photoId != null) 'photo_id': photoId,
      if (localPath != null) 'local_path': localPath,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPhotosCompanion copyWith({
    Value<String>? photoId,
    Value<String>? localPath,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return LocalPhotosCompanion(
      photoId: photoId ?? this.photoId,
      localPath: localPath ?? this.localPath,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (photoId.present) {
      map['photo_id'] = Variable<String>(photoId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPhotosCompanion(')
          ..write('photoId: $photoId, ')
          ..write('localPath: $localPath, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HouseholdsTable households = $HouseholdsTable(this);
  late final $HouseholdMembersTable householdMembers = $HouseholdMembersTable(
    this,
  );
  late final $CatsTable cats = $CatsTable(this);
  late final $RecordTypesTable recordTypes = $RecordTypesTable(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $RecordPhotosTable recordPhotos = $RecordPhotosTable(this);
  late final $AppStatesTable appStates = $AppStatesTable(this);
  late final $PendingChangesTable pendingChanges = $PendingChangesTable(this);
  late final $PendingPhotosTable pendingPhotos = $PendingPhotosTable(this);
  late final $LocalPhotosTable localPhotos = $LocalPhotosTable(this);
  late final Index recordsCatRecordedAt = Index(
    'records_cat_recorded_at',
    'CREATE INDEX records_cat_recorded_at ON records (cat_id, recorded_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    households,
    householdMembers,
    cats,
    recordTypes,
    records,
    recordPhotos,
    appStates,
    pendingChanges,
    pendingPhotos,
    localPhotos,
    recordsCatRecordedAt,
  ];
}

typedef $$HouseholdsTableCreateCompanionBuilder = HouseholdsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  required String name,
  Value<int> rowid,
});
typedef $$HouseholdsTableUpdateCompanionBuilder = HouseholdsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  Value<String> name,
  Value<int> rowid,
});

final class $$HouseholdsTableReferences
    extends BaseReferences<_$AppDatabase, $HouseholdsTable, HouseholdRow> {
  $$HouseholdsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CatsTable, List<CatRow>> _catsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cats,
    aliasName: 'households__id__cats__household_id',
  );

  $$CatsTableProcessedTableManager get catsRefs {
    final manager = $$CatsTableTableManager(
      $_db,
      $_db.cats,
    ).filter((f) => f.householdId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_catsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecordTypesTable, List<RecordTypeRow>>
  _recordTypesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recordTypes,
    aliasName: 'households__id__record_types__household_id',
  );

  $$RecordTypesTableProcessedTableManager get recordTypesRefs {
    final manager = $$RecordTypesTableTableManager(
      $_db,
      $_db.recordTypes,
    ).filter((f) => f.householdId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordTypesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HouseholdsTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> catsRefs(
    Expression<bool> Function($$CatsTableFilterComposer f) f,
  ) {
    final $$CatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cats,
      getReferencedColumn: (t) => t.householdId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatsTableFilterComposer(
            $db: $db,
            $table: $db.cats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recordTypesRefs(
    Expression<bool> Function($$RecordTypesTableFilterComposer f) f,
  ) {
    final $$RecordTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordTypes,
      getReferencedColumn: (t) => t.householdId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordTypesTableFilterComposer(
            $db: $db,
            $table: $db.recordTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HouseholdsTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HouseholdsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> catsRefs<T extends Object>(
    Expression<T> Function($$CatsTableAnnotationComposer a) f,
  ) {
    final $$CatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cats,
      getReferencedColumn: (t) => t.householdId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatsTableAnnotationComposer(
            $db: $db,
            $table: $db.cats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recordTypesRefs<T extends Object>(
    Expression<T> Function($$RecordTypesTableAnnotationComposer a) f,
  ) {
    final $$RecordTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordTypes,
      getReferencedColumn: (t) => t.householdId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.recordTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HouseholdsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HouseholdsTable,
          HouseholdRow,
          $$HouseholdsTableFilterComposer,
          $$HouseholdsTableOrderingComposer,
          $$HouseholdsTableAnnotationComposer,
          $$HouseholdsTableCreateCompanionBuilder,
          $$HouseholdsTableUpdateCompanionBuilder,
          (HouseholdRow, $$HouseholdsTableReferences),
          HouseholdRow,
          PrefetchHooks Function({bool catsRefs, bool recordTypesRefs})
        > {
  $$HouseholdsTableTableManager(_$AppDatabase db, $HouseholdsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => HouseholdsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HouseholdsTable, HouseholdRow>(table),
                  $$HouseholdsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catsRefs = false, recordTypesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (catsRefs) db.cats,
                if (recordTypesRefs) db.recordTypes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (catsRefs)
                    await $_getPrefetchedDataByColumns<
                      HouseholdRow,
                      $HouseholdsTable,
                      CatRow,
                      $CatsTable
                    >(
                      currentTable: table,
                      referencedTable: $$HouseholdsTableReferences
                          ._catsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HouseholdsTableReferences(db, table, p0).catsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'household_id',
                      typedResults: items,
                    ),
                  if (recordTypesRefs)
                    await $_getPrefetchedDataByColumns<
                      HouseholdRow,
                      $HouseholdsTable,
                      RecordTypeRow,
                      $RecordTypesTable
                    >(
                      currentTable: table,
                      referencedTable: $$HouseholdsTableReferences
                          ._recordTypesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HouseholdsTableReferences(
                            db,
                            table,
                            p0,
                          ).recordTypesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'household_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$HouseholdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HouseholdsTable,
      HouseholdRow,
      $$HouseholdsTableFilterComposer,
      $$HouseholdsTableOrderingComposer,
      $$HouseholdsTableAnnotationComposer,
      $$HouseholdsTableCreateCompanionBuilder,
      $$HouseholdsTableUpdateCompanionBuilder,
      (HouseholdRow, $$HouseholdsTableReferences),
      HouseholdRow,
      PrefetchHooks Function({bool catsRefs, bool recordTypesRefs})
    >;
typedef $$HouseholdMembersTableCreateCompanionBuilder =
    HouseholdMembersCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      required String householdId,
      required String userId,
      Value<String?> displayName,
      Value<int> rowid,
    });
typedef $$HouseholdMembersTableUpdateCompanionBuilder =
    HouseholdMembersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      Value<String> householdId,
      Value<String> userId,
      Value<String?> displayName,
      Value<int> rowid,
    });

class $$HouseholdMembersTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HouseholdMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HouseholdMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );
}

class $$HouseholdMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HouseholdMembersTable,
          HouseholdMemberRow,
          $$HouseholdMembersTableFilterComposer,
          $$HouseholdMembersTableOrderingComposer,
          $$HouseholdMembersTableAnnotationComposer,
          $$HouseholdMembersTableCreateCompanionBuilder,
          $$HouseholdMembersTableUpdateCompanionBuilder,
          (
            HouseholdMemberRow,
            BaseReferences<
              _$AppDatabase,
              $HouseholdMembersTable,
              HouseholdMemberRow
            >,
          ),
          HouseholdMemberRow,
          PrefetchHooks Function()
        > {
  $$HouseholdMembersTableTableManager(
    _$AppDatabase db,
    $HouseholdMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdMembersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                userId: userId,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String householdId,
                required String userId,
                Value<String?> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdMembersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                userId: userId,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HouseholdMembersTable, HouseholdMemberRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $HouseholdMembersTable,
                    HouseholdMemberRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HouseholdMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HouseholdMembersTable,
      HouseholdMemberRow,
      $$HouseholdMembersTableFilterComposer,
      $$HouseholdMembersTableOrderingComposer,
      $$HouseholdMembersTableAnnotationComposer,
      $$HouseholdMembersTableCreateCompanionBuilder,
      $$HouseholdMembersTableUpdateCompanionBuilder,
      (
        HouseholdMemberRow,
        BaseReferences<
          _$AppDatabase,
          $HouseholdMembersTable,
          HouseholdMemberRow
        >,
      ),
      HouseholdMemberRow,
      PrefetchHooks Function()
    >;
typedef $$CatsTableCreateCompanionBuilder = CatsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  required String householdId,
  required String name,
  Value<DateTime?> birthDate,
  Value<String?> sex,
  Value<String?> conditions,
  Value<String?> iconPath,
  Value<String> status,
  Value<int> rowid,
});
typedef $$CatsTableUpdateCompanionBuilder = CatsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  Value<String> householdId,
  Value<String> name,
  Value<DateTime?> birthDate,
  Value<String?> sex,
  Value<String?> conditions,
  Value<String?> iconPath,
  Value<String> status,
  Value<int> rowid,
});

final class $$CatsTableReferences
    extends BaseReferences<_$AppDatabase, $CatsTable, CatRow> {
  $$CatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HouseholdsTable _householdIdTable(_$AppDatabase db) =>
      db.households.createAlias('cats__household_id__households__id');

  $$HouseholdsTableProcessedTableManager get householdId {
    final $_column = $_itemColumn<String>('household_id')!;

    final manager = $$HouseholdsTableTableManager(
      $_db,
      $_db.households,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_householdIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecordsTable, List<RecordRow>> _recordsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.records,
    aliasName: 'cats__id__records__cat_id',
  );

  $$RecordsTableProcessedTableManager get recordsRefs {
    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.catId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatsTableFilterComposer extends Composer<_$AppDatabase, $CatsTable> {
  $$CatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconPath => $composableBuilder(
    column: $table.iconPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$HouseholdsTableFilterComposer get householdId {
    final $$HouseholdsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableFilterComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recordsRefs(
    Expression<bool> Function($$RecordsTableFilterComposer f) f,
  ) {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.catId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatsTableOrderingComposer extends Composer<_$AppDatabase, $CatsTable> {
  $$CatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconPath => $composableBuilder(
    column: $table.iconPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$HouseholdsTableOrderingComposer get householdId {
    final $$HouseholdsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableOrderingComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatsTable> {
  $$CatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconPath =>
      $composableBuilder(column: $table.iconPath, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$HouseholdsTableAnnotationComposer get householdId {
    final $$HouseholdsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableAnnotationComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recordsRefs<T extends Object>(
    Expression<T> Function($$RecordsTableAnnotationComposer a) f,
  ) {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.catId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatsTable,
          CatRow,
          $$CatsTableFilterComposer,
          $$CatsTableOrderingComposer,
          $$CatsTableAnnotationComposer,
          $$CatsTableCreateCompanionBuilder,
          $$CatsTableUpdateCompanionBuilder,
          (CatRow, $$CatsTableReferences),
          CatRow,
          PrefetchHooks Function({bool householdId, bool recordsRefs})
        > {
  $$CatsTableTableManager(_$AppDatabase db, $CatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> conditions = const Value.absent(),
                Value<String?> iconPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                name: name,
                birthDate: birthDate,
                sex: sex,
                conditions: conditions,
                iconPath: iconPath,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String householdId,
                required String name,
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> conditions = const Value.absent(),
                Value<String?> iconPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                name: name,
                birthDate: birthDate,
                sex: sex,
                conditions: conditions,
                iconPath: iconPath,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatsTable, CatRow>(table),
                  $$CatsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({householdId = false, recordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recordsRefs) db.records],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (householdId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.householdId,
                        referencedTable: $$CatsTableReferences
                            ._householdIdTable(db),
                        referencedColumn: $$CatsTableReferences
                            ._householdIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recordsRefs)
                    await $_getPrefetchedDataByColumns<
                      CatRow,
                      $CatsTable,
                      RecordRow,
                      $RecordsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CatsTableReferences._recordsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$CatsTableReferences(db, table, p0).recordsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'cat_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatsTable,
      CatRow,
      $$CatsTableFilterComposer,
      $$CatsTableOrderingComposer,
      $$CatsTableAnnotationComposer,
      $$CatsTableCreateCompanionBuilder,
      $$CatsTableUpdateCompanionBuilder,
      (CatRow, $$CatsTableReferences),
      CatRow,
      PrefetchHooks Function({bool householdId, bool recordsRefs})
    >;
typedef $$RecordTypesTableCreateCompanionBuilder =
    RecordTypesCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      required String householdId,
      required String name,
      Value<String?> icon,
      required String kind,
      Value<int> sortOrder,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$RecordTypesTableUpdateCompanionBuilder =
    RecordTypesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      Value<String> householdId,
      Value<String> name,
      Value<String?> icon,
      Value<String> kind,
      Value<int> sortOrder,
      Value<bool> hidden,
      Value<int> rowid,
    });

final class $$RecordTypesTableReferences
    extends BaseReferences<_$AppDatabase, $RecordTypesTable, RecordTypeRow> {
  $$RecordTypesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HouseholdsTable _householdIdTable(_$AppDatabase db) =>
      db.households.createAlias('record_types__household_id__households__id');

  $$HouseholdsTableProcessedTableManager get householdId {
    final $_column = $_itemColumn<String>('household_id')!;

    final manager = $$HouseholdsTableTableManager(
      $_db,
      $_db.households,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_householdIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecordsTable, List<RecordRow>> _recordsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.records,
    aliasName: 'record_types__id__records__record_type_id',
  );

  $$RecordsTableProcessedTableManager get recordsRefs {
    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.recordTypeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecordTypesTableFilterComposer
    extends Composer<_$AppDatabase, $RecordTypesTable> {
  $$RecordTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  $$HouseholdsTableFilterComposer get householdId {
    final $$HouseholdsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableFilterComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recordsRefs(
    Expression<bool> Function($$RecordsTableFilterComposer f) f,
  ) {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.recordTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordTypesTable> {
  $$RecordTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  $$HouseholdsTableOrderingComposer get householdId {
    final $$HouseholdsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableOrderingComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordTypesTable> {
  $$RecordTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  $$HouseholdsTableAnnotationComposer get householdId {
    final $$HouseholdsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.householdId,
      referencedTable: $db.households,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HouseholdsTableAnnotationComposer(
            $db: $db,
            $table: $db.households,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recordsRefs<T extends Object>(
    Expression<T> Function($$RecordsTableAnnotationComposer a) f,
  ) {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.recordTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordTypesTable,
          RecordTypeRow,
          $$RecordTypesTableFilterComposer,
          $$RecordTypesTableOrderingComposer,
          $$RecordTypesTableAnnotationComposer,
          $$RecordTypesTableCreateCompanionBuilder,
          $$RecordTypesTableUpdateCompanionBuilder,
          (RecordTypeRow, $$RecordTypesTableReferences),
          RecordTypeRow,
          PrefetchHooks Function({bool householdId, bool recordsRefs})
        > {
  $$RecordTypesTableTableManager(_$AppDatabase db, $RecordTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordTypesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                name: name,
                icon: icon,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String householdId,
                required String name,
                Value<String?> icon = const Value.absent(),
                required String kind,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordTypesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                householdId: householdId,
                name: name,
                icon: icon,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordTypesTable, RecordTypeRow>(table),
                  $$RecordTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({householdId = false, recordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recordsRefs) db.records],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (householdId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.householdId,
                        referencedTable: $$RecordTypesTableReferences
                            ._householdIdTable(db),
                        referencedColumn: $$RecordTypesTableReferences
                            ._householdIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recordsRefs)
                    await $_getPrefetchedDataByColumns<
                      RecordTypeRow,
                      $RecordTypesTable,
                      RecordRow,
                      $RecordsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RecordTypesTableReferences
                          ._recordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RecordTypesTableReferences(
                            db,
                            table,
                            p0,
                          ).recordsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'record_type_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RecordTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordTypesTable,
      RecordTypeRow,
      $$RecordTypesTableFilterComposer,
      $$RecordTypesTableOrderingComposer,
      $$RecordTypesTableAnnotationComposer,
      $$RecordTypesTableCreateCompanionBuilder,
      $$RecordTypesTableUpdateCompanionBuilder,
      (RecordTypeRow, $$RecordTypesTableReferences),
      RecordTypeRow,
      PrefetchHooks Function({bool householdId, bool recordsRefs})
    >;
typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  required String catId,
  required String recordTypeId,
  required DateTime recordedAt,
  Value<String?> authorId,
  required String authorName,
  Value<double?> valueNumber,
  Value<String?> level,
  Value<String?> detail,
  Value<String?> memo,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> serverSeq,
  Value<String> catId,
  Value<String> recordTypeId,
  Value<DateTime> recordedAt,
  Value<String?> authorId,
  Value<String> authorName,
  Value<double?> valueNumber,
  Value<String?> level,
  Value<String?> detail,
  Value<String?> memo,
  Value<int> rowid,
});

final class $$RecordsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordsTable, RecordRow> {
  $$RecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CatsTable _catIdTable(_$AppDatabase db) =>
      db.cats.createAlias('records__cat_id__cats__id');

  $$CatsTableProcessedTableManager get catId {
    final $_column = $_itemColumn<String>('cat_id')!;

    final manager = $$CatsTableTableManager(
      $_db,
      $_db.cats,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RecordTypesTable _recordTypeIdTable(_$AppDatabase db) =>
      db.recordTypes.createAlias('records__record_type_id__record_types__id');

  $$RecordTypesTableProcessedTableManager get recordTypeId {
    final $_column = $_itemColumn<String>('record_type_id')!;

    final manager = $$RecordTypesTableTableManager(
      $_db,
      $_db.recordTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecordPhotosTable, List<RecordPhotoRow>>
  _recordPhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recordPhotos,
    aliasName: 'records__id__record_photos__record_id',
  );

  $$RecordPhotosTableProcessedTableManager get recordPhotosRefs {
    final manager = $$RecordPhotosTableTableManager(
      $_db,
      $_db.recordPhotos,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  $$CatsTableFilterComposer get catId {
    final $$CatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catId,
      referencedTable: $db.cats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatsTableFilterComposer(
            $db: $db,
            $table: $db.cats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecordTypesTableFilterComposer get recordTypeId {
    final $$RecordTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordTypeId,
      referencedTable: $db.recordTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordTypesTableFilterComposer(
            $db: $db,
            $table: $db.recordTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recordPhotosRefs(
    Expression<bool> Function($$RecordPhotosTableFilterComposer f) f,
  ) {
    final $$RecordPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordPhotos,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordPhotosTableFilterComposer(
            $db: $db,
            $table: $db.recordPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatsTableOrderingComposer get catId {
    final $$CatsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catId,
      referencedTable: $db.cats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatsTableOrderingComposer(
            $db: $db,
            $table: $db.cats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecordTypesTableOrderingComposer get recordTypeId {
    final $$RecordTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordTypeId,
      referencedTable: $db.recordTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordTypesTableOrderingComposer(
            $db: $db,
            $table: $db.recordTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  $$CatsTableAnnotationComposer get catId {
    final $$CatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catId,
      referencedTable: $db.cats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatsTableAnnotationComposer(
            $db: $db,
            $table: $db.cats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecordTypesTableAnnotationComposer get recordTypeId {
    final $$RecordTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordTypeId,
      referencedTable: $db.recordTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.recordTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recordPhotosRefs<T extends Object>(
    Expression<T> Function($$RecordPhotosTableAnnotationComposer a) f,
  ) {
    final $$RecordPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordPhotos,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.recordPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (RecordRow, $$RecordsTableReferences),
          RecordRow,
          PrefetchHooks Function({
            bool catId,
            bool recordTypeId,
            bool recordPhotosRefs,
          })
        > {
  $$RecordsTableTableManager(_$AppDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> catId = const Value.absent(),
                Value<String> recordTypeId = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<String> authorName = const Value.absent(),
                Value<double?> valueNumber = const Value.absent(),
                Value<String?> level = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                catId: catId,
                recordTypeId: recordTypeId,
                recordedAt: recordedAt,
                authorId: authorId,
                authorName: authorName,
                valueNumber: valueNumber,
                level: level,
                detail: detail,
                memo: memo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String catId,
                required String recordTypeId,
                required DateTime recordedAt,
                Value<String?> authorId = const Value.absent(),
                required String authorName,
                Value<double?> valueNumber = const Value.absent(),
                Value<String?> level = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                catId: catId,
                recordTypeId: recordTypeId,
                recordedAt: recordedAt,
                authorId: authorId,
                authorName: authorName,
                valueNumber: valueNumber,
                level: level,
                detail: detail,
                memo: memo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, RecordRow>(table),
                  $$RecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                catId = false,
                recordTypeId = false,
                recordPhotosRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recordPhotosRefs) db.recordPhotos,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (catId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.catId,
                            referencedTable: $$RecordsTableReferences
                                ._catIdTable(db),
                            referencedColumn: $$RecordsTableReferences
                                ._catIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (recordTypeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.recordTypeId,
                            referencedTable: $$RecordsTableReferences
                                ._recordTypeIdTable(db),
                            referencedColumn: $$RecordsTableReferences
                                ._recordTypeIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recordPhotosRefs)
                        await $_getPrefetchedDataByColumns<
                          RecordRow,
                          $RecordsTable,
                          RecordPhotoRow,
                          $RecordPhotosTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecordsTableReferences
                              ._recordPhotosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).recordPhotosRefs,
                          currentColumn: 'id',
                          referencedColumn: 'record_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, $$RecordsTableReferences),
      RecordRow,
      PrefetchHooks Function({
        bool catId,
        bool recordTypeId,
        bool recordPhotosRefs,
      })
    >;
typedef $$RecordPhotosTableCreateCompanionBuilder =
    RecordPhotosCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      required String recordId,
      required int sortOrder,
      Value<int?> sizeBytes,
      Value<bool> uploaded,
      Value<int> rowid,
    });
typedef $$RecordPhotosTableUpdateCompanionBuilder =
    RecordPhotosCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> serverSeq,
      Value<String> recordId,
      Value<int> sortOrder,
      Value<int?> sizeBytes,
      Value<bool> uploaded,
      Value<int> rowid,
    });

final class $$RecordPhotosTableReferences
    extends BaseReferences<_$AppDatabase, $RecordPhotosTable, RecordPhotoRow> {
  $$RecordPhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordsTable _recordIdTable(_$AppDatabase db) =>
      db.records.createAlias('record_photos__record_id__records__id');

  $$RecordsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecordPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $RecordPhotosTable> {
  $$RecordPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordsTableFilterComposer get recordId {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordPhotosTable> {
  $$RecordPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordsTableOrderingComposer get recordId {
    final $$RecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableOrderingComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordPhotosTable> {
  $$RecordPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get uploaded =>
      $composableBuilder(column: $table.uploaded, builder: (column) => column);

  $$RecordsTableAnnotationComposer get recordId {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordPhotosTable,
          RecordPhotoRow,
          $$RecordPhotosTableFilterComposer,
          $$RecordPhotosTableOrderingComposer,
          $$RecordPhotosTableAnnotationComposer,
          $$RecordPhotosTableCreateCompanionBuilder,
          $$RecordPhotosTableUpdateCompanionBuilder,
          (RecordPhotoRow, $$RecordPhotosTableReferences),
          RecordPhotoRow,
          PrefetchHooks Function({bool recordId})
        > {
  $$RecordPhotosTableTableManager(_$AppDatabase db, $RecordPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> uploaded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordPhotosCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                recordId: recordId,
                sortOrder: sortOrder,
                sizeBytes: sizeBytes,
                uploaded: uploaded,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required String recordId,
                required int sortOrder,
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> uploaded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordPhotosCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverSeq: serverSeq,
                recordId: recordId,
                sortOrder: sortOrder,
                sizeBytes: sizeBytes,
                uploaded: uploaded,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordPhotosTable, RecordPhotoRow>(table),
                  $$RecordPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordId,
                        referencedTable: $$RecordPhotosTableReferences
                            ._recordIdTable(db),
                        referencedColumn: $$RecordPhotosTableReferences
                            ._recordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecordPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordPhotosTable,
      RecordPhotoRow,
      $$RecordPhotosTableFilterComposer,
      $$RecordPhotosTableOrderingComposer,
      $$RecordPhotosTableAnnotationComposer,
      $$RecordPhotosTableCreateCompanionBuilder,
      $$RecordPhotosTableUpdateCompanionBuilder,
      (RecordPhotoRow, $$RecordPhotosTableReferences),
      RecordPhotoRow,
      PrefetchHooks Function({bool recordId})
    >;
typedef $$AppStatesTableCreateCompanionBuilder = AppStatesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppStatesTableUpdateCompanionBuilder = AppStatesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppStatesTableFilterComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppStatesTable,
          AppStateRow,
          $$AppStatesTableFilterComposer,
          $$AppStatesTableOrderingComposer,
          $$AppStatesTableAnnotationComposer,
          $$AppStatesTableCreateCompanionBuilder,
          $$AppStatesTableUpdateCompanionBuilder,
          (
            AppStateRow,
            BaseReferences<_$AppDatabase, $AppStatesTable, AppStateRow>,
          ),
          AppStateRow,
          PrefetchHooks Function()
        > {
  $$AppStatesTableTableManager(_$AppDatabase db, $AppStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppStatesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppStatesTable, AppStateRow>(table),
                  BaseReferences<_$AppDatabase, $AppStatesTable, AppStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppStatesTable,
      AppStateRow,
      $$AppStatesTableFilterComposer,
      $$AppStatesTableOrderingComposer,
      $$AppStatesTableAnnotationComposer,
      $$AppStatesTableCreateCompanionBuilder,
      $$AppStatesTableUpdateCompanionBuilder,
      (
        AppStateRow,
        BaseReferences<_$AppDatabase, $AppStatesTable, AppStateRow>,
      ),
      AppStateRow,
      PrefetchHooks Function()
    >;
typedef $$PendingChangesTableCreateCompanionBuilder =
    PendingChangesCompanion Function({
      Value<int> seq,
      required String userId,
      required String targetTable,
      required String rowId,
      required String operation,
      required String payload,
      Value<int> attempts,
    });
typedef $$PendingChangesTableUpdateCompanionBuilder =
    PendingChangesCompanion Function({
      Value<int> seq,
      Value<String> userId,
      Value<String> targetTable,
      Value<String> rowId,
      Value<String> operation,
      Value<String> payload,
      Value<int> attempts,
    });

class $$PendingChangesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingChangesTable> {
  $$PendingChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingChangesTable> {
  $$PendingChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingChangesTable> {
  $$PendingChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$PendingChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingChangesTable,
          PendingChangeRow,
          $$PendingChangesTableFilterComposer,
          $$PendingChangesTableOrderingComposer,
          $$PendingChangesTableAnnotationComposer,
          $$PendingChangesTableCreateCompanionBuilder,
          $$PendingChangesTableUpdateCompanionBuilder,
          (
            PendingChangeRow,
            BaseReferences<
              _$AppDatabase,
              $PendingChangesTable,
              PendingChangeRow
            >,
          ),
          PendingChangeRow,
          PrefetchHooks Function()
        > {
  $$PendingChangesTableTableManager(
    _$AppDatabase db,
    $PendingChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => PendingChangesCompanion(
                seq: seq,
                userId: userId,
                targetTable: targetTable,
                rowId: rowId,
                operation: operation,
                payload: payload,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String userId,
                required String targetTable,
                required String rowId,
                required String operation,
                required String payload,
                Value<int> attempts = const Value.absent(),
              }) => PendingChangesCompanion.insert(
                seq: seq,
                userId: userId,
                targetTable: targetTable,
                rowId: rowId,
                operation: operation,
                payload: payload,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingChangesTable, PendingChangeRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingChangesTable,
                    PendingChangeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingChangesTable,
      PendingChangeRow,
      $$PendingChangesTableFilterComposer,
      $$PendingChangesTableOrderingComposer,
      $$PendingChangesTableAnnotationComposer,
      $$PendingChangesTableCreateCompanionBuilder,
      $$PendingChangesTableUpdateCompanionBuilder,
      (
        PendingChangeRow,
        BaseReferences<_$AppDatabase, $PendingChangesTable, PendingChangeRow>,
      ),
      PendingChangeRow,
      PrefetchHooks Function()
    >;
typedef $$PendingPhotosTableCreateCompanionBuilder =
    PendingPhotosCompanion Function({
      required String photoId,
      required String userId,
      required String localPath,
      Value<int> rowid,
    });
typedef $$PendingPhotosTableUpdateCompanionBuilder =
    PendingPhotosCompanion Function({
      Value<String> photoId,
      Value<String> userId,
      Value<String> localPath,
      Value<int> rowid,
    });

class $$PendingPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get photoId =>
      $composableBuilder(column: $table.photoId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);
}

class $$PendingPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingPhotosTable,
          PendingPhotoRow,
          $$PendingPhotosTableFilterComposer,
          $$PendingPhotosTableOrderingComposer,
          $$PendingPhotosTableAnnotationComposer,
          $$PendingPhotosTableCreateCompanionBuilder,
          $$PendingPhotosTableUpdateCompanionBuilder,
          (
            PendingPhotoRow,
            BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhotoRow>,
          ),
          PendingPhotoRow,
          PrefetchHooks Function()
        > {
  $$PendingPhotosTableTableManager(_$AppDatabase db, $PendingPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> photoId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPhotosCompanion(
                photoId: photoId,
                userId: userId,
                localPath: localPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String photoId,
                required String userId,
                required String localPath,
                Value<int> rowid = const Value.absent(),
              }) => PendingPhotosCompanion.insert(
                photoId: photoId,
                userId: userId,
                localPath: localPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingPhotosTable, PendingPhotoRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingPhotosTable,
                    PendingPhotoRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingPhotosTable,
      PendingPhotoRow,
      $$PendingPhotosTableFilterComposer,
      $$PendingPhotosTableOrderingComposer,
      $$PendingPhotosTableAnnotationComposer,
      $$PendingPhotosTableCreateCompanionBuilder,
      $$PendingPhotosTableUpdateCompanionBuilder,
      (
        PendingPhotoRow,
        BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhotoRow>,
      ),
      PendingPhotoRow,
      PrefetchHooks Function()
    >;
typedef $$LocalPhotosTableCreateCompanionBuilder =
    LocalPhotosCompanion Function({
      required String photoId,
      required String localPath,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$LocalPhotosTableUpdateCompanionBuilder =
    LocalPhotosCompanion Function({
      Value<String> photoId,
      Value<String> localPath,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$LocalPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPhotosTable> {
  $$LocalPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPhotosTable> {
  $$LocalPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPhotosTable> {
  $$LocalPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get photoId =>
      $composableBuilder(column: $table.photoId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$LocalPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPhotosTable,
          LocalPhotoRow,
          $$LocalPhotosTableFilterComposer,
          $$LocalPhotosTableOrderingComposer,
          $$LocalPhotosTableAnnotationComposer,
          $$LocalPhotosTableCreateCompanionBuilder,
          $$LocalPhotosTableUpdateCompanionBuilder,
          (
            LocalPhotoRow,
            BaseReferences<_$AppDatabase, $LocalPhotosTable, LocalPhotoRow>,
          ),
          LocalPhotoRow,
          PrefetchHooks Function()
        > {
  $$LocalPhotosTableTableManager(_$AppDatabase db, $LocalPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> photoId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPhotosCompanion(
                photoId: photoId,
                localPath: localPath,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String photoId,
                required String localPath,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalPhotosCompanion.insert(
                photoId: photoId,
                localPath: localPath,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPhotosTable, LocalPhotoRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalPhotosTable,
                    LocalPhotoRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPhotosTable,
      LocalPhotoRow,
      $$LocalPhotosTableFilterComposer,
      $$LocalPhotosTableOrderingComposer,
      $$LocalPhotosTableAnnotationComposer,
      $$LocalPhotosTableCreateCompanionBuilder,
      $$LocalPhotosTableUpdateCompanionBuilder,
      (
        LocalPhotoRow,
        BaseReferences<_$AppDatabase, $LocalPhotosTable, LocalPhotoRow>,
      ),
      LocalPhotoRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HouseholdsTableTableManager get households =>
      $$HouseholdsTableTableManager(_db, _db.households);
  $$HouseholdMembersTableTableManager get householdMembers =>
      $$HouseholdMembersTableTableManager(_db, _db.householdMembers);
  $$CatsTableTableManager get cats => $$CatsTableTableManager(_db, _db.cats);
  $$RecordTypesTableTableManager get recordTypes =>
      $$RecordTypesTableTableManager(_db, _db.recordTypes);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$RecordPhotosTableTableManager get recordPhotos =>
      $$RecordPhotosTableTableManager(_db, _db.recordPhotos);
  $$AppStatesTableTableManager get appStates =>
      $$AppStatesTableTableManager(_db, _db.appStates);
  $$PendingChangesTableTableManager get pendingChanges =>
      $$PendingChangesTableTableManager(_db, _db.pendingChanges);
  $$PendingPhotosTableTableManager get pendingPhotos =>
      $$PendingPhotosTableTableManager(_db, _db.pendingPhotos);
  $$LocalPhotosTableTableManager get localPhotos =>
      $$LocalPhotosTableTableManager(_db, _db.localPhotos);
}
