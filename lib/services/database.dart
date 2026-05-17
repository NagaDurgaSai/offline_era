import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get peerIp => text()();
  TextColumn get senderName => text()();
  TextColumn get senderIp => text()();
  TextColumn get content => text()();
  TextColumn get type => text()();
  TextColumn get timestamp => text()();
  BoolColumn get isMe => boolean()();
  TextColumn get fileName => text().nullable()();
  TextColumn get savedPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class KnownDevices extends Table {
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  TextColumn get ip => text()();
  TextColumn get name => text()();
  IntColumn get port => integer()();
  TextColumn get lastSeen => text()();

  @override
  Set<Column> get primaryKey => {ip};
}

@DriftDatabase(tables: [Messages, KnownDevices])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(knownDevices);
      }
      if (from < 3) {
        await m.addColumn(knownDevices, knownDevices.deviceId);
      }
    },
  );

  Future<List<Message>> messagesForPeer(String peerIp) =>
      (select(messages)
            ..where((m) => m.peerIp.equals(peerIp))
            ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
          .get();

  Future<void> insertMessage(MessagesCompanion msg) =>
      into(messages).insertOnConflictUpdate(msg);

  Future<void> deleteMessagesForPeer(String peerIp) =>
      (delete(messages)..where((m) => m.peerIp.equals(peerIp))).go();

  Future<List<KnownDevice>> getAllKnownDevices() =>
      select(knownDevices).get();

  Future<void> upsertKnownDevice(KnownDevicesCompanion device) =>
      into(knownDevices).insertOnConflictUpdate(device);

  Future<void> deleteKnownDevice(String ip) =>
      (delete(knownDevices)..where((d) => d.ip.equals(ip))).go();

  Future<void> deleteKnownDeviceByDeviceId(String deviceId) =>
      (delete(knownDevices)..where((d) => d.deviceId.equals(deviceId))).go();

  Future<KnownDevice?> getKnownDeviceByDeviceId(String deviceId) async {
    final results = await (select(knownDevices)
          ..where((d) => d.deviceId.equals(deviceId)))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Future<Message?> lastMessageForPeer(String peerIp) async {
    final results = await (select(messages)
          ..where((m) => m.peerIp.equals(peerIp))
          ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'offline_era.db'));
    return NativeDatabase.createInBackground(file);
  });
}
