// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScanLogTable extends ScanLog with TableInfo<$ScanLogTable, ScanLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
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
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ScanSource, String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ScanSource>($ScanLogTable.$convertersource);
  static const VerificationMeta _nfcUidMeta = const VerificationMeta('nfcUid');
  @override
  late final GeneratedColumn<String> nfcUid = GeneratedColumn<String>(
    'nfc_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nfcRecordsMeta = const VerificationMeta('nfcRecords');
  @override
  late final GeneratedColumn<String> nfcRecords = GeneratedColumn<String>(
    'nfc_records',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MatchType, String> matchType = GeneratedColumn<String>(
    'match_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MatchType>($ScanLogTable.$convertermatchType);
  static const VerificationMeta _matchIdMeta = const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchLabelMeta = const VerificationMeta('matchLabel');
  @override
  late final GeneratedColumn<String> matchLabel = GeneratedColumn<String>(
    'match_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceInfoMeta = const VerificationMeta('deviceInfo');
  @override
  late final GeneratedColumn<String> deviceInfo = GeneratedColumn<String>(
    'device_info',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    value,
    format,
    source,
    nfcUid,
    nfcRecords,
    matchType,
    matchId,
    matchLabel,
    scannedAt,
    deviceInfo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_log';
  @override
  VerificationContext validateIntegrity(Insertable<ScanLogEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta, format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('nfc_uid')) {
      context.handle(_nfcUidMeta, nfcUid.isAcceptableOrUnknown(data['nfc_uid']!, _nfcUidMeta));
    }
    if (data.containsKey('nfc_records')) {
      context.handle(_nfcRecordsMeta, nfcRecords.isAcceptableOrUnknown(data['nfc_records']!, _nfcRecordsMeta));
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta, matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    }
    if (data.containsKey('match_label')) {
      context.handle(_matchLabelMeta, matchLabel.isAcceptableOrUnknown(data['match_label']!, _matchLabelMeta));
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta, scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    if (data.containsKey('device_info')) {
      context.handle(_deviceInfoMeta, deviceInfo.isAcceptableOrUnknown(data['device_info']!, _deviceInfoMeta));
    } else if (isInserting) {
      context.missing(_deviceInfoMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanLogEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      format: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      source: $ScanLogTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      ),
      nfcUid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}nfc_uid']),
      nfcRecords: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}nfc_records']),
      matchType: $ScanLogTable.$convertermatchType.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}match_type'])!,
      ),
      matchId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}match_id']),
      matchLabel: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}match_label']),
      scannedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}scanned_at'])!,
      deviceInfo: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_info'])!,
    );
  }

  @override
  $ScanLogTable createAlias(String alias) {
    return $ScanLogTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ScanSource, String, String> $convertersource = const EnumNameConverter<ScanSource>(
    ScanSource.values,
  );
  static JsonTypeConverter2<MatchType, String, String> $convertermatchType = const EnumNameConverter<MatchType>(
    MatchType.values,
  );
}

class ScanLogEntry extends DataClass implements Insertable<ScanLogEntry> {
  final int id;

  /// Raw text: the barcode / QR value, the first NDEF text or URI record, or "NFC:<uid>".
  final String value;

  /// qr, code128, ean13, datamatrix, nfc, manual …
  final String format;
  final ScanSource source;
  final String? nfcUid;

  /// JSON list of the decoded NDEF records (see `NdefRecordInfo`).
  final String? nfcRecords;
  final MatchType matchType;
  final String? matchId;
  final String? matchLabel;
  final DateTime scannedAt;
  final String deviceInfo;
  const ScanLogEntry({
    required this.id,
    required this.value,
    required this.format,
    required this.source,
    this.nfcUid,
    this.nfcRecords,
    required this.matchType,
    this.matchId,
    this.matchLabel,
    required this.scannedAt,
    required this.deviceInfo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['value'] = Variable<String>(value);
    map['format'] = Variable<String>(format);
    {
      map['source'] = Variable<String>($ScanLogTable.$convertersource.toSql(source));
    }
    if (!nullToAbsent || nfcUid != null) {
      map['nfc_uid'] = Variable<String>(nfcUid);
    }
    if (!nullToAbsent || nfcRecords != null) {
      map['nfc_records'] = Variable<String>(nfcRecords);
    }
    {
      map['match_type'] = Variable<String>($ScanLogTable.$convertermatchType.toSql(matchType));
    }
    if (!nullToAbsent || matchId != null) {
      map['match_id'] = Variable<String>(matchId);
    }
    if (!nullToAbsent || matchLabel != null) {
      map['match_label'] = Variable<String>(matchLabel);
    }
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    map['device_info'] = Variable<String>(deviceInfo);
    return map;
  }

  ScanLogCompanion toCompanion(bool nullToAbsent) {
    return ScanLogCompanion(
      id: Value(id),
      value: Value(value),
      format: Value(format),
      source: Value(source),
      nfcUid: nfcUid == null && nullToAbsent ? const Value.absent() : Value(nfcUid),
      nfcRecords: nfcRecords == null && nullToAbsent ? const Value.absent() : Value(nfcRecords),
      matchType: Value(matchType),
      matchId: matchId == null && nullToAbsent ? const Value.absent() : Value(matchId),
      matchLabel: matchLabel == null && nullToAbsent ? const Value.absent() : Value(matchLabel),
      scannedAt: Value(scannedAt),
      deviceInfo: Value(deviceInfo),
    );
  }

  factory ScanLogEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanLogEntry(
      id: serializer.fromJson<int>(json['id']),
      value: serializer.fromJson<String>(json['value']),
      format: serializer.fromJson<String>(json['format']),
      source: $ScanLogTable.$convertersource.fromJson(serializer.fromJson<String>(json['source'])),
      nfcUid: serializer.fromJson<String?>(json['nfcUid']),
      nfcRecords: serializer.fromJson<String?>(json['nfcRecords']),
      matchType: $ScanLogTable.$convertermatchType.fromJson(serializer.fromJson<String>(json['matchType'])),
      matchId: serializer.fromJson<String?>(json['matchId']),
      matchLabel: serializer.fromJson<String?>(json['matchLabel']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      deviceInfo: serializer.fromJson<String>(json['deviceInfo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'value': serializer.toJson<String>(value),
      'format': serializer.toJson<String>(format),
      'source': serializer.toJson<String>($ScanLogTable.$convertersource.toJson(source)),
      'nfcUid': serializer.toJson<String?>(nfcUid),
      'nfcRecords': serializer.toJson<String?>(nfcRecords),
      'matchType': serializer.toJson<String>($ScanLogTable.$convertermatchType.toJson(matchType)),
      'matchId': serializer.toJson<String?>(matchId),
      'matchLabel': serializer.toJson<String?>(matchLabel),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'deviceInfo': serializer.toJson<String>(deviceInfo),
    };
  }

  ScanLogEntry copyWith({
    int? id,
    String? value,
    String? format,
    ScanSource? source,
    Value<String?> nfcUid = const Value.absent(),
    Value<String?> nfcRecords = const Value.absent(),
    MatchType? matchType,
    Value<String?> matchId = const Value.absent(),
    Value<String?> matchLabel = const Value.absent(),
    DateTime? scannedAt,
    String? deviceInfo,
  }) => ScanLogEntry(
    id: id ?? this.id,
    value: value ?? this.value,
    format: format ?? this.format,
    source: source ?? this.source,
    nfcUid: nfcUid.present ? nfcUid.value : this.nfcUid,
    nfcRecords: nfcRecords.present ? nfcRecords.value : this.nfcRecords,
    matchType: matchType ?? this.matchType,
    matchId: matchId.present ? matchId.value : this.matchId,
    matchLabel: matchLabel.present ? matchLabel.value : this.matchLabel,
    scannedAt: scannedAt ?? this.scannedAt,
    deviceInfo: deviceInfo ?? this.deviceInfo,
  );
  ScanLogEntry copyWithCompanion(ScanLogCompanion data) {
    return ScanLogEntry(
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      format: data.format.present ? data.format.value : this.format,
      source: data.source.present ? data.source.value : this.source,
      nfcUid: data.nfcUid.present ? data.nfcUid.value : this.nfcUid,
      nfcRecords: data.nfcRecords.present ? data.nfcRecords.value : this.nfcRecords,
      matchType: data.matchType.present ? data.matchType.value : this.matchType,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      matchLabel: data.matchLabel.present ? data.matchLabel.value : this.matchLabel,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      deviceInfo: data.deviceInfo.present ? data.deviceInfo.value : this.deviceInfo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanLogEntry(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('format: $format, ')
          ..write('source: $source, ')
          ..write('nfcUid: $nfcUid, ')
          ..write('nfcRecords: $nfcRecords, ')
          ..write('matchType: $matchType, ')
          ..write('matchId: $matchId, ')
          ..write('matchLabel: $matchLabel, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('deviceInfo: $deviceInfo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, value, format, source, nfcUid, nfcRecords, matchType, matchId, matchLabel, scannedAt, deviceInfo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanLogEntry &&
          other.id == this.id &&
          other.value == this.value &&
          other.format == this.format &&
          other.source == this.source &&
          other.nfcUid == this.nfcUid &&
          other.nfcRecords == this.nfcRecords &&
          other.matchType == this.matchType &&
          other.matchId == this.matchId &&
          other.matchLabel == this.matchLabel &&
          other.scannedAt == this.scannedAt &&
          other.deviceInfo == this.deviceInfo);
}

class ScanLogCompanion extends UpdateCompanion<ScanLogEntry> {
  final Value<int> id;
  final Value<String> value;
  final Value<String> format;
  final Value<ScanSource> source;
  final Value<String?> nfcUid;
  final Value<String?> nfcRecords;
  final Value<MatchType> matchType;
  final Value<String?> matchId;
  final Value<String?> matchLabel;
  final Value<DateTime> scannedAt;
  final Value<String> deviceInfo;
  const ScanLogCompanion({
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.format = const Value.absent(),
    this.source = const Value.absent(),
    this.nfcUid = const Value.absent(),
    this.nfcRecords = const Value.absent(),
    this.matchType = const Value.absent(),
    this.matchId = const Value.absent(),
    this.matchLabel = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.deviceInfo = const Value.absent(),
  });
  ScanLogCompanion.insert({
    this.id = const Value.absent(),
    required String value,
    required String format,
    required ScanSource source,
    this.nfcUid = const Value.absent(),
    this.nfcRecords = const Value.absent(),
    required MatchType matchType,
    this.matchId = const Value.absent(),
    this.matchLabel = const Value.absent(),
    required DateTime scannedAt,
    required String deviceInfo,
  }) : value = Value(value),
       format = Value(format),
       source = Value(source),
       matchType = Value(matchType),
       scannedAt = Value(scannedAt),
       deviceInfo = Value(deviceInfo);
  static Insertable<ScanLogEntry> custom({
    Expression<int>? id,
    Expression<String>? value,
    Expression<String>? format,
    Expression<String>? source,
    Expression<String>? nfcUid,
    Expression<String>? nfcRecords,
    Expression<String>? matchType,
    Expression<String>? matchId,
    Expression<String>? matchLabel,
    Expression<DateTime>? scannedAt,
    Expression<String>? deviceInfo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (format != null) 'format': format,
      if (source != null) 'source': source,
      if (nfcUid != null) 'nfc_uid': nfcUid,
      if (nfcRecords != null) 'nfc_records': nfcRecords,
      if (matchType != null) 'match_type': matchType,
      if (matchId != null) 'match_id': matchId,
      if (matchLabel != null) 'match_label': matchLabel,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (deviceInfo != null) 'device_info': deviceInfo,
    });
  }

  ScanLogCompanion copyWith({
    Value<int>? id,
    Value<String>? value,
    Value<String>? format,
    Value<ScanSource>? source,
    Value<String?>? nfcUid,
    Value<String?>? nfcRecords,
    Value<MatchType>? matchType,
    Value<String?>? matchId,
    Value<String?>? matchLabel,
    Value<DateTime>? scannedAt,
    Value<String>? deviceInfo,
  }) {
    return ScanLogCompanion(
      id: id ?? this.id,
      value: value ?? this.value,
      format: format ?? this.format,
      source: source ?? this.source,
      nfcUid: nfcUid ?? this.nfcUid,
      nfcRecords: nfcRecords ?? this.nfcRecords,
      matchType: matchType ?? this.matchType,
      matchId: matchId ?? this.matchId,
      matchLabel: matchLabel ?? this.matchLabel,
      scannedAt: scannedAt ?? this.scannedAt,
      deviceInfo: deviceInfo ?? this.deviceInfo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (source.present) {
      map['source'] = Variable<String>($ScanLogTable.$convertersource.toSql(source.value));
    }
    if (nfcUid.present) {
      map['nfc_uid'] = Variable<String>(nfcUid.value);
    }
    if (nfcRecords.present) {
      map['nfc_records'] = Variable<String>(nfcRecords.value);
    }
    if (matchType.present) {
      map['match_type'] = Variable<String>($ScanLogTable.$convertermatchType.toSql(matchType.value));
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (matchLabel.present) {
      map['match_label'] = Variable<String>(matchLabel.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (deviceInfo.present) {
      map['device_info'] = Variable<String>(deviceInfo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanLogCompanion(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('format: $format, ')
          ..write('source: $source, ')
          ..write('nfcUid: $nfcUid, ')
          ..write('nfcRecords: $nfcRecords, ')
          ..write('matchType: $matchType, ')
          ..write('matchId: $matchId, ')
          ..write('matchLabel: $matchLabel, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('deviceInfo: $deviceInfo')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations with TableInfo<$LocationsTable, DbLocation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _siteMeta = const VerificationMeta('site');
  @override
  late final GeneratedColumn<String> site = GeneratedColumn<String>(
    'site',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _buildingMeta = const VerificationMeta('building');
  @override
  late final GeneratedColumn<String> building = GeneratedColumn<String>(
    'building',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _floorMeta = const VerificationMeta('floor');
  @override
  late final GeneratedColumn<String> floor = GeneratedColumn<String>(
    'floor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
    'room',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocationLevel, String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<LocationLevel>($LocationsTable.$converterlevel);
  @override
  List<GeneratedColumn> get $columns => [id, code, site, building, floor, room, level];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(Insertable<DbLocation> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(_codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('site')) {
      context.handle(_siteMeta, site.isAcceptableOrUnknown(data['site']!, _siteMeta));
    } else if (isInserting) {
      context.missing(_siteMeta);
    }
    if (data.containsKey('building')) {
      context.handle(_buildingMeta, building.isAcceptableOrUnknown(data['building']!, _buildingMeta));
    }
    if (data.containsKey('floor')) {
      context.handle(_floorMeta, floor.isAcceptableOrUnknown(data['floor']!, _floorMeta));
    }
    if (data.containsKey('room')) {
      context.handle(_roomMeta, room.isAcceptableOrUnknown(data['room']!, _roomMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbLocation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbLocation(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      site: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}site'])!,
      building: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}building']),
      floor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}floor']),
      room: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}room']),
      level: $LocationsTable.$converterlevel.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      ),
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocationLevel, String, String> $converterlevel = const EnumNameConverter<LocationLevel>(
    LocationLevel.values,
  );
}

class DbLocation extends DataClass implements Insertable<DbLocation> {
  final int id;
  final String code;
  final String site;
  final String? building;
  final String? floor;
  final String? room;
  final LocationLevel level;
  const DbLocation({
    required this.id,
    required this.code,
    required this.site,
    this.building,
    this.floor,
    this.room,
    required this.level,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['site'] = Variable<String>(site);
    if (!nullToAbsent || building != null) {
      map['building'] = Variable<String>(building);
    }
    if (!nullToAbsent || floor != null) {
      map['floor'] = Variable<String>(floor);
    }
    if (!nullToAbsent || room != null) {
      map['room'] = Variable<String>(room);
    }
    {
      map['level'] = Variable<String>($LocationsTable.$converterlevel.toSql(level));
    }
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      code: Value(code),
      site: Value(site),
      building: building == null && nullToAbsent ? const Value.absent() : Value(building),
      floor: floor == null && nullToAbsent ? const Value.absent() : Value(floor),
      room: room == null && nullToAbsent ? const Value.absent() : Value(room),
      level: Value(level),
    );
  }

  factory DbLocation.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbLocation(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      site: serializer.fromJson<String>(json['site']),
      building: serializer.fromJson<String?>(json['building']),
      floor: serializer.fromJson<String?>(json['floor']),
      room: serializer.fromJson<String?>(json['room']),
      level: $LocationsTable.$converterlevel.fromJson(serializer.fromJson<String>(json['level'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'site': serializer.toJson<String>(site),
      'building': serializer.toJson<String?>(building),
      'floor': serializer.toJson<String?>(floor),
      'room': serializer.toJson<String?>(room),
      'level': serializer.toJson<String>($LocationsTable.$converterlevel.toJson(level)),
    };
  }

  DbLocation copyWith({
    int? id,
    String? code,
    String? site,
    Value<String?> building = const Value.absent(),
    Value<String?> floor = const Value.absent(),
    Value<String?> room = const Value.absent(),
    LocationLevel? level,
  }) => DbLocation(
    id: id ?? this.id,
    code: code ?? this.code,
    site: site ?? this.site,
    building: building.present ? building.value : this.building,
    floor: floor.present ? floor.value : this.floor,
    room: room.present ? room.value : this.room,
    level: level ?? this.level,
  );
  DbLocation copyWithCompanion(LocationsCompanion data) {
    return DbLocation(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      site: data.site.present ? data.site.value : this.site,
      building: data.building.present ? data.building.value : this.building,
      floor: data.floor.present ? data.floor.value : this.floor,
      room: data.room.present ? data.room.value : this.room,
      level: data.level.present ? data.level.value : this.level,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbLocation(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('site: $site, ')
          ..write('building: $building, ')
          ..write('floor: $floor, ')
          ..write('room: $room, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, site, building, floor, room, level);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbLocation &&
          other.id == this.id &&
          other.code == this.code &&
          other.site == this.site &&
          other.building == this.building &&
          other.floor == this.floor &&
          other.room == this.room &&
          other.level == this.level);
}

class LocationsCompanion extends UpdateCompanion<DbLocation> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> site;
  final Value<String?> building;
  final Value<String?> floor;
  final Value<String?> room;
  final Value<LocationLevel> level;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.site = const Value.absent(),
    this.building = const Value.absent(),
    this.floor = const Value.absent(),
    this.room = const Value.absent(),
    this.level = const Value.absent(),
  });
  LocationsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String site,
    this.building = const Value.absent(),
    this.floor = const Value.absent(),
    this.room = const Value.absent(),
    required LocationLevel level,
  }) : code = Value(code),
       site = Value(site),
       level = Value(level);
  static Insertable<DbLocation> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? site,
    Expression<String>? building,
    Expression<String>? floor,
    Expression<String>? room,
    Expression<String>? level,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (site != null) 'site': site,
      if (building != null) 'building': building,
      if (floor != null) 'floor': floor,
      if (room != null) 'room': room,
      if (level != null) 'level': level,
    });
  }

  LocationsCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<String>? site,
    Value<String?>? building,
    Value<String?>? floor,
    Value<String?>? room,
    Value<LocationLevel>? level,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      site: site ?? this.site,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      room: room ?? this.room,
      level: level ?? this.level,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (site.present) {
      map['site'] = Variable<String>(site.value);
    }
    if (building.present) {
      map['building'] = Variable<String>(building.value);
    }
    if (floor.present) {
      map['floor'] = Variable<String>(floor.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (level.present) {
      map['level'] = Variable<String>($LocationsTable.$converterlevel.toSql(level.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('site: $site, ')
          ..write('building: $building, ')
          ..write('floor: $floor, ')
          ..write('room: $room, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }
}

class $TagLinksTable extends TagLinks with TableInfo<$TagLinksTable, TagLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _tagKeyMeta = const VerificationMeta('tagKey');
  @override
  late final GeneratedColumn<String> tagKey = GeneratedColumn<String>(
    'tag_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TagType, String> tagType = GeneratedColumn<String>(
    'tag_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TagType>($TagLinksTable.$convertertagType);
  @override
  late final GeneratedColumnWithTypeConverter<LinkTarget, String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<LinkTarget>($TagLinksTable.$convertertargetType);
  static const VerificationMeta _targetIdMeta = const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tagKey, tagType, targetType, targetId, label, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_links';
  @override
  VerificationContext validateIntegrity(Insertable<TagLink> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tag_key')) {
      context.handle(_tagKeyMeta, tagKey.isAcceptableOrUnknown(data['tag_key']!, _tagKeyMeta));
    } else if (isInserting) {
      context.missing(_tagKeyMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta, targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagLink(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tagKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_key'])!,
      tagType: $TagLinksTable.$convertertagType.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_type'])!,
      ),
      targetType: $TagLinksTable.$convertertargetType.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target_type'])!,
      ),
      targetId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target_id'])!,
      label: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TagLinksTable createAlias(String alias) {
    return $TagLinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TagType, String, String> $convertertagType = const EnumNameConverter<TagType>(
    TagType.values,
  );
  static JsonTypeConverter2<LinkTarget, String, String> $convertertargetType = const EnumNameConverter<LinkTarget>(
    LinkTarget.values,
  );
}

class TagLink extends DataClass implements Insertable<TagLink> {
  final int id;
  final String tagKey;
  final TagType tagType;
  final LinkTarget targetType;
  final String targetId;
  final String label;
  final DateTime createdAt;
  const TagLink({
    required this.id,
    required this.tagKey,
    required this.tagType,
    required this.targetType,
    required this.targetId,
    required this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tag_key'] = Variable<String>(tagKey);
    {
      map['tag_type'] = Variable<String>($TagLinksTable.$convertertagType.toSql(tagType));
    }
    {
      map['target_type'] = Variable<String>($TagLinksTable.$convertertargetType.toSql(targetType));
    }
    map['target_id'] = Variable<String>(targetId);
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagLinksCompanion toCompanion(bool nullToAbsent) {
    return TagLinksCompanion(
      id: Value(id),
      tagKey: Value(tagKey),
      tagType: Value(tagType),
      targetType: Value(targetType),
      targetId: Value(targetId),
      label: Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory TagLink.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagLink(
      id: serializer.fromJson<int>(json['id']),
      tagKey: serializer.fromJson<String>(json['tagKey']),
      tagType: $TagLinksTable.$convertertagType.fromJson(serializer.fromJson<String>(json['tagType'])),
      targetType: $TagLinksTable.$convertertargetType.fromJson(serializer.fromJson<String>(json['targetType'])),
      targetId: serializer.fromJson<String>(json['targetId']),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tagKey': serializer.toJson<String>(tagKey),
      'tagType': serializer.toJson<String>($TagLinksTable.$convertertagType.toJson(tagType)),
      'targetType': serializer.toJson<String>($TagLinksTable.$convertertargetType.toJson(targetType)),
      'targetId': serializer.toJson<String>(targetId),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TagLink copyWith({
    int? id,
    String? tagKey,
    TagType? tagType,
    LinkTarget? targetType,
    String? targetId,
    String? label,
    DateTime? createdAt,
  }) => TagLink(
    id: id ?? this.id,
    tagKey: tagKey ?? this.tagKey,
    tagType: tagType ?? this.tagType,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    label: label ?? this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  TagLink copyWithCompanion(TagLinksCompanion data) {
    return TagLink(
      id: data.id.present ? data.id.value : this.id,
      tagKey: data.tagKey.present ? data.tagKey.value : this.tagKey,
      tagType: data.tagType.present ? data.tagType.value : this.tagType,
      targetType: data.targetType.present ? data.targetType.value : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagLink(')
          ..write('id: $id, ')
          ..write('tagKey: $tagKey, ')
          ..write('tagType: $tagType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tagKey, tagType, targetType, targetId, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagLink &&
          other.id == this.id &&
          other.tagKey == this.tagKey &&
          other.tagType == this.tagType &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class TagLinksCompanion extends UpdateCompanion<TagLink> {
  final Value<int> id;
  final Value<String> tagKey;
  final Value<TagType> tagType;
  final Value<LinkTarget> targetType;
  final Value<String> targetId;
  final Value<String> label;
  final Value<DateTime> createdAt;
  const TagLinksCompanion({
    this.id = const Value.absent(),
    this.tagKey = const Value.absent(),
    this.tagType = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TagLinksCompanion.insert({
    this.id = const Value.absent(),
    required String tagKey,
    required TagType tagType,
    required LinkTarget targetType,
    required String targetId,
    required String label,
    required DateTime createdAt,
  }) : tagKey = Value(tagKey),
       tagType = Value(tagType),
       targetType = Value(targetType),
       targetId = Value(targetId),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<TagLink> custom({
    Expression<int>? id,
    Expression<String>? tagKey,
    Expression<String>? tagType,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tagKey != null) 'tag_key': tagKey,
      if (tagType != null) 'tag_type': tagType,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TagLinksCompanion copyWith({
    Value<int>? id,
    Value<String>? tagKey,
    Value<TagType>? tagType,
    Value<LinkTarget>? targetType,
    Value<String>? targetId,
    Value<String>? label,
    Value<DateTime>? createdAt,
  }) {
    return TagLinksCompanion(
      id: id ?? this.id,
      tagKey: tagKey ?? this.tagKey,
      tagType: tagType ?? this.tagType,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tagKey.present) {
      map['tag_key'] = Variable<String>(tagKey.value);
    }
    if (tagType.present) {
      map['tag_type'] = Variable<String>($TagLinksTable.$convertertagType.toSql(tagType.value));
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>($TagLinksTable.$convertertargetType.toSql(targetType.value));
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagLinksCompanion(')
          ..write('id: $id, ')
          ..write('tagKey: $tagKey, ')
          ..write('tagType: $tagType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScanLogTable scanLog = $ScanLogTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $TagLinksTable tagLinks = $TagLinksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scanLog, locations, tagLinks];
}

typedef $$ScanLogTableCreateCompanionBuilder =
    ScanLogCompanion Function({
      Value<int> id,
      required String value,
      required String format,
      required ScanSource source,
      Value<String?> nfcUid,
      Value<String?> nfcRecords,
      required MatchType matchType,
      Value<String?> matchId,
      Value<String?> matchLabel,
      required DateTime scannedAt,
      required String deviceInfo,
    });
typedef $$ScanLogTableUpdateCompanionBuilder =
    ScanLogCompanion Function({
      Value<int> id,
      Value<String> value,
      Value<String> format,
      Value<ScanSource> source,
      Value<String?> nfcUid,
      Value<String?> nfcRecords,
      Value<MatchType> matchType,
      Value<String?> matchId,
      Value<String?> matchLabel,
      Value<DateTime> scannedAt,
      Value<String> deviceInfo,
    });

class $$ScanLogTableFilterComposer extends Composer<_$AppDatabase, $ScanLogTable> {
  $$ScanLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ScanSource, ScanSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get nfcUid =>
      $composableBuilder(column: $table.nfcUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nfcRecords =>
      $composableBuilder(column: $table.nfcRecords, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MatchType, MatchType, String> get matchType =>
      $composableBuilder(column: $table.matchType, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchLabel =>
      $composableBuilder(column: $table.matchLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceInfo =>
      $composableBuilder(column: $table.deviceInfo, builder: (column) => ColumnFilters(column));
}

class $$ScanLogTableOrderingComposer extends Composer<_$AppDatabase, $ScanLogTable> {
  $$ScanLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nfcUid =>
      $composableBuilder(column: $table.nfcUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nfcRecords =>
      $composableBuilder(column: $table.nfcRecords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchType =>
      $composableBuilder(column: $table.matchType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchLabel =>
      $composableBuilder(column: $table.matchLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceInfo =>
      $composableBuilder(column: $table.deviceInfo, builder: (column) => ColumnOrderings(column));
}

class $$ScanLogTableAnnotationComposer extends Composer<_$AppDatabase, $ScanLogTable> {
  $$ScanLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get format => $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ScanSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get nfcUid => $composableBuilder(column: $table.nfcUid, builder: (column) => column);

  GeneratedColumn<String> get nfcRecords => $composableBuilder(column: $table.nfcRecords, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MatchType, String> get matchType =>
      $composableBuilder(column: $table.matchType, builder: (column) => column);

  GeneratedColumn<String> get matchId => $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get matchLabel => $composableBuilder(column: $table.matchLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt => $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceInfo => $composableBuilder(column: $table.deviceInfo, builder: (column) => column);
}

class $$ScanLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanLogTable,
          ScanLogEntry,
          $$ScanLogTableFilterComposer,
          $$ScanLogTableOrderingComposer,
          $$ScanLogTableAnnotationComposer,
          $$ScanLogTableCreateCompanionBuilder,
          $$ScanLogTableUpdateCompanionBuilder,
          (ScanLogEntry, BaseReferences<_$AppDatabase, $ScanLogTable, ScanLogEntry>),
          ScanLogEntry,
          PrefetchHooks Function()
        > {
  $$ScanLogTableTableManager(_$AppDatabase db, $ScanLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ScanLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ScanLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ScanLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<ScanSource> source = const Value.absent(),
                Value<String?> nfcUid = const Value.absent(),
                Value<String?> nfcRecords = const Value.absent(),
                Value<MatchType> matchType = const Value.absent(),
                Value<String?> matchId = const Value.absent(),
                Value<String?> matchLabel = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
                Value<String> deviceInfo = const Value.absent(),
              }) => ScanLogCompanion(
                id: id,
                value: value,
                format: format,
                source: source,
                nfcUid: nfcUid,
                nfcRecords: nfcRecords,
                matchType: matchType,
                matchId: matchId,
                matchLabel: matchLabel,
                scannedAt: scannedAt,
                deviceInfo: deviceInfo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String value,
                required String format,
                required ScanSource source,
                Value<String?> nfcUid = const Value.absent(),
                Value<String?> nfcRecords = const Value.absent(),
                required MatchType matchType,
                Value<String?> matchId = const Value.absent(),
                Value<String?> matchLabel = const Value.absent(),
                required DateTime scannedAt,
                required String deviceInfo,
              }) => ScanLogCompanion.insert(
                id: id,
                value: value,
                format: format,
                source: source,
                nfcUid: nfcUid,
                nfcRecords: nfcRecords,
                matchType: matchType,
                matchId: matchId,
                matchLabel: matchLabel,
                scannedAt: scannedAt,
                deviceInfo: deviceInfo,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanLogTable,
      ScanLogEntry,
      $$ScanLogTableFilterComposer,
      $$ScanLogTableOrderingComposer,
      $$ScanLogTableAnnotationComposer,
      $$ScanLogTableCreateCompanionBuilder,
      $$ScanLogTableUpdateCompanionBuilder,
      (ScanLogEntry, BaseReferences<_$AppDatabase, $ScanLogTable, ScanLogEntry>),
      ScanLogEntry,
      PrefetchHooks Function()
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      required String code,
      required String site,
      Value<String?> building,
      Value<String?> floor,
      Value<String?> room,
      required LocationLevel level,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<String> site,
      Value<String?> building,
      Value<String?> floor,
      Value<String?> room,
      Value<LocationLevel> level,
    });

class $$LocationsTableFilterComposer extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get site => $composableBuilder(column: $table.site, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get building =>
      $composableBuilder(column: $table.building, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get floor =>
      $composableBuilder(column: $table.floor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get room => $composableBuilder(column: $table.room, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<LocationLevel, LocationLevel, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$LocationsTableOrderingComposer extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get site =>
      $composableBuilder(column: $table.site, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get building =>
      $composableBuilder(column: $table.building, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get floor =>
      $composableBuilder(column: $table.floor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => ColumnOrderings(column));
}

class $$LocationsTableAnnotationComposer extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code => $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get site => $composableBuilder(column: $table.site, builder: (column) => column);

  GeneratedColumn<String> get building => $composableBuilder(column: $table.building, builder: (column) => column);

  GeneratedColumn<String> get floor => $composableBuilder(column: $table.floor, builder: (column) => column);

  GeneratedColumn<String> get room => $composableBuilder(column: $table.room, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocationLevel, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          DbLocation,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (DbLocation, BaseReferences<_$AppDatabase, $LocationsTable, DbLocation>),
          DbLocation,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> site = const Value.absent(),
                Value<String?> building = const Value.absent(),
                Value<String?> floor = const Value.absent(),
                Value<String?> room = const Value.absent(),
                Value<LocationLevel> level = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                code: code,
                site: site,
                building: building,
                floor: floor,
                room: room,
                level: level,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                required String site,
                Value<String?> building = const Value.absent(),
                Value<String?> floor = const Value.absent(),
                Value<String?> room = const Value.absent(),
                required LocationLevel level,
              }) => LocationsCompanion.insert(
                id: id,
                code: code,
                site: site,
                building: building,
                floor: floor,
                room: room,
                level: level,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      DbLocation,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (DbLocation, BaseReferences<_$AppDatabase, $LocationsTable, DbLocation>),
      DbLocation,
      PrefetchHooks Function()
    >;
typedef $$TagLinksTableCreateCompanionBuilder =
    TagLinksCompanion Function({
      Value<int> id,
      required String tagKey,
      required TagType tagType,
      required LinkTarget targetType,
      required String targetId,
      required String label,
      required DateTime createdAt,
    });
typedef $$TagLinksTableUpdateCompanionBuilder =
    TagLinksCompanion Function({
      Value<int> id,
      Value<String> tagKey,
      Value<TagType> tagType,
      Value<LinkTarget> targetType,
      Value<String> targetId,
      Value<String> label,
      Value<DateTime> createdAt,
    });

class $$TagLinksTableFilterComposer extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagKey =>
      $composableBuilder(column: $table.tagKey, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TagType, TagType, String> get tagType =>
      $composableBuilder(column: $table.tagType, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<LinkTarget, LinkTarget, String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TagLinksTableOrderingComposer extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagKey =>
      $composableBuilder(column: $table.tagKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagType =>
      $composableBuilder(column: $table.tagType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TagLinksTableAnnotationComposer extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tagKey => $composableBuilder(column: $table.tagKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TagType, String> get tagType =>
      $composableBuilder(column: $table.tagType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LinkTarget, String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => column);

  GeneratedColumn<String> get targetId => $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get label => $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TagLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagLinksTable,
          TagLink,
          $$TagLinksTableFilterComposer,
          $$TagLinksTableOrderingComposer,
          $$TagLinksTableAnnotationComposer,
          $$TagLinksTableCreateCompanionBuilder,
          $$TagLinksTableUpdateCompanionBuilder,
          (TagLink, BaseReferences<_$AppDatabase, $TagLinksTable, TagLink>),
          TagLink,
          PrefetchHooks Function()
        > {
  $$TagLinksTableTableManager(_$AppDatabase db, $TagLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TagLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TagLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TagLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tagKey = const Value.absent(),
                Value<TagType> tagType = const Value.absent(),
                Value<LinkTarget> targetType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TagLinksCompanion(
                id: id,
                tagKey: tagKey,
                tagType: tagType,
                targetType: targetType,
                targetId: targetId,
                label: label,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tagKey,
                required TagType tagType,
                required LinkTarget targetType,
                required String targetId,
                required String label,
                required DateTime createdAt,
              }) => TagLinksCompanion.insert(
                id: id,
                tagKey: tagKey,
                tagType: tagType,
                targetType: targetType,
                targetId: targetId,
                label: label,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagLinksTable,
      TagLink,
      $$TagLinksTableFilterComposer,
      $$TagLinksTableOrderingComposer,
      $$TagLinksTableAnnotationComposer,
      $$TagLinksTableCreateCompanionBuilder,
      $$TagLinksTableUpdateCompanionBuilder,
      (TagLink, BaseReferences<_$AppDatabase, $TagLinksTable, TagLink>),
      TagLink,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScanLogTableTableManager get scanLog => $$ScanLogTableTableManager(_db, _db.scanLog);
  $$LocationsTableTableManager get locations => $$LocationsTableTableManager(_db, _db.locations);
  $$TagLinksTableTableManager get tagLinks => $$TagLinksTableTableManager(_db, _db.tagLinks);
}
