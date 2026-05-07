// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _peerIpMeta = const VerificationMeta('peerIp');
  @override
  late final GeneratedColumn<String> peerIp = GeneratedColumn<String>(
      'peer_ip', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIpMeta =
      const VerificationMeta('senderIp');
  @override
  late final GeneratedColumn<String> senderIp = GeneratedColumn<String>(
      'sender_ip', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
      'is_me', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_me" IN (0, 1))'));
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _savedPathMeta =
      const VerificationMeta('savedPath');
  @override
  late final GeneratedColumn<String> savedPath = GeneratedColumn<String>(
      'saved_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        peerIp,
        senderName,
        senderIp,
        content,
        type,
        timestamp,
        isMe,
        fileName,
        savedPath
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_ip')) {
      context.handle(_peerIpMeta,
          peerIp.isAcceptableOrUnknown(data['peer_ip']!, _peerIpMeta));
    } else if (isInserting) {
      context.missing(_peerIpMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    } else if (isInserting) {
      context.missing(_senderNameMeta);
    }
    if (data.containsKey('sender_ip')) {
      context.handle(_senderIpMeta,
          senderIp.isAcceptableOrUnknown(data['sender_ip']!, _senderIpMeta));
    } else if (isInserting) {
      context.missing(_senderIpMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_me')) {
      context.handle(
          _isMeMeta, isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta));
    } else if (isInserting) {
      context.missing(_isMeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    }
    if (data.containsKey('saved_path')) {
      context.handle(_savedPathMeta,
          savedPath.isAcceptableOrUnknown(data['saved_path']!, _savedPathMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      peerIp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}peer_ip'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name'])!,
      senderIp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_ip'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timestamp'])!,
      isMe: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_me'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name']),
      savedPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}saved_path']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String peerIp;
  final String senderName;
  final String senderIp;
  final String content;
  final String type;
  final String timestamp;
  final bool isMe;
  final String? fileName;
  final String? savedPath;
  const Message(
      {required this.id,
      required this.peerIp,
      required this.senderName,
      required this.senderIp,
      required this.content,
      required this.type,
      required this.timestamp,
      required this.isMe,
      this.fileName,
      this.savedPath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_ip'] = Variable<String>(peerIp);
    map['sender_name'] = Variable<String>(senderName);
    map['sender_ip'] = Variable<String>(senderIp);
    map['content'] = Variable<String>(content);
    map['type'] = Variable<String>(type);
    map['timestamp'] = Variable<String>(timestamp);
    map['is_me'] = Variable<bool>(isMe);
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || savedPath != null) {
      map['saved_path'] = Variable<String>(savedPath);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      peerIp: Value(peerIp),
      senderName: Value(senderName),
      senderIp: Value(senderIp),
      content: Value(content),
      type: Value(type),
      timestamp: Value(timestamp),
      isMe: Value(isMe),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      savedPath: savedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(savedPath),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      peerIp: serializer.fromJson<String>(json['peerIp']),
      senderName: serializer.fromJson<String>(json['senderName']),
      senderIp: serializer.fromJson<String>(json['senderIp']),
      content: serializer.fromJson<String>(json['content']),
      type: serializer.fromJson<String>(json['type']),
      timestamp: serializer.fromJson<String>(json['timestamp']),
      isMe: serializer.fromJson<bool>(json['isMe']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      savedPath: serializer.fromJson<String?>(json['savedPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerIp': serializer.toJson<String>(peerIp),
      'senderName': serializer.toJson<String>(senderName),
      'senderIp': serializer.toJson<String>(senderIp),
      'content': serializer.toJson<String>(content),
      'type': serializer.toJson<String>(type),
      'timestamp': serializer.toJson<String>(timestamp),
      'isMe': serializer.toJson<bool>(isMe),
      'fileName': serializer.toJson<String?>(fileName),
      'savedPath': serializer.toJson<String?>(savedPath),
    };
  }

  Message copyWith(
          {String? id,
          String? peerIp,
          String? senderName,
          String? senderIp,
          String? content,
          String? type,
          String? timestamp,
          bool? isMe,
          Value<String?> fileName = const Value.absent(),
          Value<String?> savedPath = const Value.absent()}) =>
      Message(
        id: id ?? this.id,
        peerIp: peerIp ?? this.peerIp,
        senderName: senderName ?? this.senderName,
        senderIp: senderIp ?? this.senderIp,
        content: content ?? this.content,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
        isMe: isMe ?? this.isMe,
        fileName: fileName.present ? fileName.value : this.fileName,
        savedPath: savedPath.present ? savedPath.value : this.savedPath,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      peerIp: data.peerIp.present ? data.peerIp.value : this.peerIp,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      senderIp: data.senderIp.present ? data.senderIp.value : this.senderIp,
      content: data.content.present ? data.content.value : this.content,
      type: data.type.present ? data.type.value : this.type,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      savedPath: data.savedPath.present ? data.savedPath.value : this.savedPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('peerIp: $peerIp, ')
          ..write('senderName: $senderName, ')
          ..write('senderIp: $senderIp, ')
          ..write('content: $content, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('isMe: $isMe, ')
          ..write('fileName: $fileName, ')
          ..write('savedPath: $savedPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, peerIp, senderName, senderIp, content,
      type, timestamp, isMe, fileName, savedPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.peerIp == this.peerIp &&
          other.senderName == this.senderName &&
          other.senderIp == this.senderIp &&
          other.content == this.content &&
          other.type == this.type &&
          other.timestamp == this.timestamp &&
          other.isMe == this.isMe &&
          other.fileName == this.fileName &&
          other.savedPath == this.savedPath);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> peerIp;
  final Value<String> senderName;
  final Value<String> senderIp;
  final Value<String> content;
  final Value<String> type;
  final Value<String> timestamp;
  final Value<bool> isMe;
  final Value<String?> fileName;
  final Value<String?> savedPath;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.peerIp = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderIp = const Value.absent(),
    this.content = const Value.absent(),
    this.type = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isMe = const Value.absent(),
    this.fileName = const Value.absent(),
    this.savedPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String peerIp,
    required String senderName,
    required String senderIp,
    required String content,
    required String type,
    required String timestamp,
    required bool isMe,
    this.fileName = const Value.absent(),
    this.savedPath = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        peerIp = Value(peerIp),
        senderName = Value(senderName),
        senderIp = Value(senderIp),
        content = Value(content),
        type = Value(type),
        timestamp = Value(timestamp),
        isMe = Value(isMe);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? peerIp,
    Expression<String>? senderName,
    Expression<String>? senderIp,
    Expression<String>? content,
    Expression<String>? type,
    Expression<String>? timestamp,
    Expression<bool>? isMe,
    Expression<String>? fileName,
    Expression<String>? savedPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerIp != null) 'peer_ip': peerIp,
      if (senderName != null) 'sender_name': senderName,
      if (senderIp != null) 'sender_ip': senderIp,
      if (content != null) 'content': content,
      if (type != null) 'type': type,
      if (timestamp != null) 'timestamp': timestamp,
      if (isMe != null) 'is_me': isMe,
      if (fileName != null) 'file_name': fileName,
      if (savedPath != null) 'saved_path': savedPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? peerIp,
      Value<String>? senderName,
      Value<String>? senderIp,
      Value<String>? content,
      Value<String>? type,
      Value<String>? timestamp,
      Value<bool>? isMe,
      Value<String?>? fileName,
      Value<String?>? savedPath,
      Value<int>? rowid}) {
    return MessagesCompanion(
      id: id ?? this.id,
      peerIp: peerIp ?? this.peerIp,
      senderName: senderName ?? this.senderName,
      senderIp: senderIp ?? this.senderIp,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      fileName: fileName ?? this.fileName,
      savedPath: savedPath ?? this.savedPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (peerIp.present) {
      map['peer_ip'] = Variable<String>(peerIp.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (senderIp.present) {
      map['sender_ip'] = Variable<String>(senderIp.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (savedPath.present) {
      map['saved_path'] = Variable<String>(savedPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('peerIp: $peerIp, ')
          ..write('senderName: $senderName, ')
          ..write('senderIp: $senderIp, ')
          ..write('content: $content, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('isMe: $isMe, ')
          ..write('fileName: $fileName, ')
          ..write('savedPath: $savedPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnownDevicesTable extends KnownDevices
    with TableInfo<$KnownDevicesTable, KnownDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
      'ip', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
      'port', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenMeta =
      const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<String> lastSeen = GeneratedColumn<String>(
      'last_seen', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [ip, name, port, lastSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_devices';
  @override
  VerificationContext validateIntegrity(Insertable<KnownDevice> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
          _portMeta, port.isAcceptableOrUnknown(data['port']!, _portMeta));
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta,
          lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ip};
  @override
  KnownDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownDevice(
      ip: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ip'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      port: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}port'])!,
      lastSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_seen'])!,
    );
  }

  @override
  $KnownDevicesTable createAlias(String alias) {
    return $KnownDevicesTable(attachedDatabase, alias);
  }
}

class KnownDevice extends DataClass implements Insertable<KnownDevice> {
  final String ip;
  final String name;
  final int port;
  final String lastSeen;
  const KnownDevice(
      {required this.ip,
      required this.name,
      required this.port,
      required this.lastSeen});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ip'] = Variable<String>(ip);
    map['name'] = Variable<String>(name);
    map['port'] = Variable<int>(port);
    map['last_seen'] = Variable<String>(lastSeen);
    return map;
  }

  KnownDevicesCompanion toCompanion(bool nullToAbsent) {
    return KnownDevicesCompanion(
      ip: Value(ip),
      name: Value(name),
      port: Value(port),
      lastSeen: Value(lastSeen),
    );
  }

  factory KnownDevice.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownDevice(
      ip: serializer.fromJson<String>(json['ip']),
      name: serializer.fromJson<String>(json['name']),
      port: serializer.fromJson<int>(json['port']),
      lastSeen: serializer.fromJson<String>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ip': serializer.toJson<String>(ip),
      'name': serializer.toJson<String>(name),
      'port': serializer.toJson<int>(port),
      'lastSeen': serializer.toJson<String>(lastSeen),
    };
  }

  KnownDevice copyWith(
          {String? ip, String? name, int? port, String? lastSeen}) =>
      KnownDevice(
        ip: ip ?? this.ip,
        name: name ?? this.name,
        port: port ?? this.port,
        lastSeen: lastSeen ?? this.lastSeen,
      );
  KnownDevice copyWithCompanion(KnownDevicesCompanion data) {
    return KnownDevice(
      ip: data.ip.present ? data.ip.value : this.ip,
      name: data.name.present ? data.name.value : this.name,
      port: data.port.present ? data.port.value : this.port,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownDevice(')
          ..write('ip: $ip, ')
          ..write('name: $name, ')
          ..write('port: $port, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ip, name, port, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownDevice &&
          other.ip == this.ip &&
          other.name == this.name &&
          other.port == this.port &&
          other.lastSeen == this.lastSeen);
}

class KnownDevicesCompanion extends UpdateCompanion<KnownDevice> {
  final Value<String> ip;
  final Value<String> name;
  final Value<int> port;
  final Value<String> lastSeen;
  final Value<int> rowid;
  const KnownDevicesCompanion({
    this.ip = const Value.absent(),
    this.name = const Value.absent(),
    this.port = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnownDevicesCompanion.insert({
    required String ip,
    required String name,
    required int port,
    required String lastSeen,
    this.rowid = const Value.absent(),
  })  : ip = Value(ip),
        name = Value(name),
        port = Value(port),
        lastSeen = Value(lastSeen);
  static Insertable<KnownDevice> custom({
    Expression<String>? ip,
    Expression<String>? name,
    Expression<int>? port,
    Expression<String>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ip != null) 'ip': ip,
      if (name != null) 'name': name,
      if (port != null) 'port': port,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnownDevicesCompanion copyWith(
      {Value<String>? ip,
      Value<String>? name,
      Value<int>? port,
      Value<String>? lastSeen,
      Value<int>? rowid}) {
    return KnownDevicesCompanion(
      ip: ip ?? this.ip,
      name: name ?? this.name,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<String>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownDevicesCompanion(')
          ..write('ip: $ip, ')
          ..write('name: $name, ')
          ..write('port: $port, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $KnownDevicesTable knownDevices = $KnownDevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [messages, knownDevices];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String peerIp,
  required String senderName,
  required String senderIp,
  required String content,
  required String type,
  required String timestamp,
  required bool isMe,
  Value<String?> fileName,
  Value<String?> savedPath,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> peerIp,
  Value<String> senderName,
  Value<String> senderIp,
  Value<String> content,
  Value<String> type,
  Value<String> timestamp,
  Value<bool> isMe,
  Value<String?> fileName,
  Value<String?> savedPath,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get peerIp => $composableBuilder(
      column: $table.peerIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderIp => $composableBuilder(
      column: $table.senderIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get savedPath => $composableBuilder(
      column: $table.savedPath, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get peerIp => $composableBuilder(
      column: $table.peerIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderIp => $composableBuilder(
      column: $table.senderIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get savedPath => $composableBuilder(
      column: $table.savedPath, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerIp =>
      $composableBuilder(column: $table.peerIp, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get senderIp =>
      $composableBuilder(column: $table.senderIp, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get savedPath =>
      $composableBuilder(column: $table.savedPath, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> peerIp = const Value.absent(),
            Value<String> senderName = const Value.absent(),
            Value<String> senderIp = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> timestamp = const Value.absent(),
            Value<bool> isMe = const Value.absent(),
            Value<String?> fileName = const Value.absent(),
            Value<String?> savedPath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            peerIp: peerIp,
            senderName: senderName,
            senderIp: senderIp,
            content: content,
            type: type,
            timestamp: timestamp,
            isMe: isMe,
            fileName: fileName,
            savedPath: savedPath,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String peerIp,
            required String senderName,
            required String senderIp,
            required String content,
            required String type,
            required String timestamp,
            required bool isMe,
            Value<String?> fileName = const Value.absent(),
            Value<String?> savedPath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            peerIp: peerIp,
            senderName: senderName,
            senderIp: senderIp,
            content: content,
            type: type,
            timestamp: timestamp,
            isMe: isMe,
            fileName: fileName,
            savedPath: savedPath,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$KnownDevicesTableCreateCompanionBuilder = KnownDevicesCompanion
    Function({
  required String ip,
  required String name,
  required int port,
  required String lastSeen,
  Value<int> rowid,
});
typedef $$KnownDevicesTableUpdateCompanionBuilder = KnownDevicesCompanion
    Function({
  Value<String> ip,
  Value<String> name,
  Value<int> port,
  Value<String> lastSeen,
  Value<int> rowid,
});

class $$KnownDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ip => $composableBuilder(
      column: $table.ip, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get port => $composableBuilder(
      column: $table.port, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnFilters(column));
}

class $$KnownDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ip => $composableBuilder(
      column: $table.ip, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get port => $composableBuilder(
      column: $table.port, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnOrderings(column));
}

class $$KnownDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$KnownDevicesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KnownDevicesTable,
    KnownDevice,
    $$KnownDevicesTableFilterComposer,
    $$KnownDevicesTableOrderingComposer,
    $$KnownDevicesTableAnnotationComposer,
    $$KnownDevicesTableCreateCompanionBuilder,
    $$KnownDevicesTableUpdateCompanionBuilder,
    (
      KnownDevice,
      BaseReferences<_$AppDatabase, $KnownDevicesTable, KnownDevice>
    ),
    KnownDevice,
    PrefetchHooks Function()> {
  $$KnownDevicesTableTableManager(_$AppDatabase db, $KnownDevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ip = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> port = const Value.absent(),
            Value<String> lastSeen = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KnownDevicesCompanion(
            ip: ip,
            name: name,
            port: port,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ip,
            required String name,
            required int port,
            required String lastSeen,
            Value<int> rowid = const Value.absent(),
          }) =>
              KnownDevicesCompanion.insert(
            ip: ip,
            name: name,
            port: port,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KnownDevicesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KnownDevicesTable,
    KnownDevice,
    $$KnownDevicesTableFilterComposer,
    $$KnownDevicesTableOrderingComposer,
    $$KnownDevicesTableAnnotationComposer,
    $$KnownDevicesTableCreateCompanionBuilder,
    $$KnownDevicesTableUpdateCompanionBuilder,
    (
      KnownDevice,
      BaseReferences<_$AppDatabase, $KnownDevicesTable, KnownDevice>
    ),
    KnownDevice,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$KnownDevicesTableTableManager get knownDevices =>
      $$KnownDevicesTableTableManager(_db, _db.knownDevices);
}
