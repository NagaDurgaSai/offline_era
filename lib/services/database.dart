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

@DriftDatabase(tables: [Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Message>> messagesForPeer(String peerIp) =>
      (select(messages)
            ..where((m) => m.peerIp.equals(peerIp))
            ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
          .get();

  Future<void> insertMessage(MessagesCompanion msg) =>
      into(messages).insertOnConflictUpdate(msg);

  Future<void> deleteMessagesForPeer(String peerIp) =>
      (delete(messages)..where((m) => m.peerIp.equals(peerIp))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'offline_era.db'));
    return NativeDatabase.createInBackground(file);
  });
}
