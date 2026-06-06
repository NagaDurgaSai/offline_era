import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import '../models/device.dart';
import '../models/message.dart';
import '../services/database.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'discovery_service.dart';

class ChatService {
  ServerSocket? _server;
  final Map<String, Socket> _connections = {};
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _fileController = StreamController<ChatMessage>.broadcast();
  final _seenController = StreamController<String>.broadcast();
  final AppDatabase db = AppDatabase();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatMessage> get clipboardStream => _fileController.stream;
  Stream<ChatMessage> get fileStream => _fileController.stream;
  Stream<String> get seenStream => _seenController.stream;

  String _myName = '';
  String _myIp = '';
  bool isInChat = false;
  String? activeChatIp;

  final Map<String, List<ChatMessage>> _cache = {};
  final Map<String, int> _pendingNotifications = {};

  List<ChatMessage> getCachedMessages(String peerIp) {
    return _cache[peerIp] ?? [];
  }

  Future<List<ChatMessage>> historyFor(String peerIp) async {
    if (_cache.containsKey(peerIp)) return _cache[peerIp]!;
    final rows = await db.messagesForPeer(peerIp);
    final msgs = rows
        .map(
          (r) => ChatMessage(
            id: r.id,
            senderName: r.senderName,
            senderIp: r.senderIp,
            content: r.content,
            type: MessageType.values.firstWhere(
              (e) => e.name == r.type,
              orElse: () => MessageType.text,
            ),
            timestamp: DateTime.parse(r.timestamp),
            isMe: r.isMe,
            fileName: r.fileName,
            savedPath: r.savedPath,
            fileBytes: r.savedPath != null && File(r.savedPath!).existsSync()
                ? File(r.savedPath!).readAsBytesSync()
                : null,
          ),
        )
        .toList();
    _cache[peerIp] = msgs;
    return msgs;
  }

  Future<void> _persist(String peerIp, ChatMessage msg) async {
    _cache.putIfAbsent(peerIp, () => []);
    if (!_cache[peerIp]!.any((m) => m.id == msg.id)) {
      _cache[peerIp]!.add(msg);
    }
    await db.insertMessage(
      MessagesCompanion(
        id: Value(msg.id),
        peerIp: Value(peerIp),
        senderName: Value(msg.senderName),
        senderIp: Value(msg.senderIp),
        content: Value(msg.content),
        type: Value(msg.type.name),
        timestamp: Value(msg.timestamp.toIso8601String()),
        isMe: Value(msg.isMe),
        fileName: Value(msg.fileName),
        savedPath: Value(msg.savedPath),
      ),
    );
  }

  Future<void> startServer(String name, String myIp) async {
    _myName = name;
    _myIp = myIp;
    await NotificationService.init();
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      DiscoveryService.chatPort,
      shared: true,
    );
    _server!.listen(_handleIncoming);
  }

  void updateName(String name) => _myName = name;
  void clearCache(String peerIp) => _cache.remove(peerIp);

  void _handleIncoming(Socket socket) {
    final remoteIp = socket.remoteAddress.address;
    if (_connections.containsKey(remoteIp)) {
      try {
        _connections[remoteIp]?.destroy();
      } catch (_) {}
    }
    _connections[remoteIp] = socket;
    _listenOnSocket(socket, remoteIp);
  }

  void _listenOnSocket(Socket socket, String remoteIp) {
    final buffer = StringBuffer();
    socket.listen(
      (Uint8List data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer.clear();
        for (int i = 0; i < lines.length - 1; i++) {
          final chunk = lines[i].trim();
          if (chunk.isEmpty) continue;
          _handlePacket(utf8.encode(chunk), remoteIp);
        }
        if (lines.last.isNotEmpty) buffer.write(lines.last);
      },
      onDone: () => _connections.remove(remoteIp),
      onError: (_) => _connections.remove(remoteIp),
    );
  }

  void _handlePacket(Uint8List bytes, String remoteIp) async {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      final msgType = json['type'] as String;

      if (msgType == 'seen') {
        _seenController.add(remoteIp);
        return;
      }

      if (msgType == 'file_start') {
        _fileBuffers[remoteIp] = _FileBuffer(
          id: json['id'],
          senderName: json['senderName'],
          fileName: json['fileName'],
          totalSize: json['totalSize'],
          timestamp: json['timestamp'],
        );
        return;
      }

      if (msgType == 'file_chunk') {
        final buf = _fileBuffers[remoteIp];
        if (buf == null) return;
        buf.bytes.add(base64Decode(json['data'] as String));
        return;
      }

      if (msgType == 'file_end') {
        final buf = _fileBuffers.remove(remoteIp);
        if (buf == null) return;
        final allBytes = Uint8List.fromList(
          buf.bytes.expand((e) => e).toList(),
        );
        final savedPath = await StorageService.saveFile(buf.fileName, allBytes);
        final msg = ChatMessage(
          id: buf.id,
          senderName: buf.senderName,
          senderIp: remoteIp,
          content: buf.fileName,
          type: MessageType.file,
          timestamp: DateTime.parse(buf.timestamp),
          isMe: false,
          fileBytes: allBytes,
          fileName: buf.fileName,
          savedPath: savedPath,
        );
        await _persist(remoteIp, msg);
        _fileController.add(msg);
        if (activeChatIp == remoteIp) {
          await _sendSeenToIp(remoteIp);
        }
        if (!isInChat) {
          _showGroupedNotification(
            buf.senderName,
            '📁 ${buf.fileName}',
            remoteIp,
          );
        }
        return;
      }

      final msg = ChatMessage.fromJson(json, _myIp);
      await _persist(remoteIp, msg);

      if (msg.type == MessageType.text || msg.type == MessageType.code) {
        _messageController.add(msg);
        if (activeChatIp == remoteIp) {
          await _sendSeenToIp(remoteIp);
        }
        if (activeChatIp != remoteIp) {
          _showGroupedNotification(
            msg.senderName,
            msg.type == MessageType.code ? '📎 code snippet' : msg.content,
            remoteIp,
          );
        }
      } else {
        _fileController.add(msg);
      }
    } catch (_) {}
  }

  void _showGroupedNotification(
    String senderName,
    String preview,
    String peerIp,
  ) {
    _pendingNotifications[peerIp] = (_pendingNotifications[peerIp] ?? 0) + 1;
    final count = _pendingNotifications[peerIp]!;
    if (count == 1) {
      NotificationService.showMessage(senderName, preview, tag: peerIp);
    } else {
      NotificationService.showMessage(
        senderName,
        '$count new messages',
        tag: peerIp,
        id: peerIp.hashCode.abs(),
      );
    }
  }

  void clearNotificationsFor(String peerIp) {
    _pendingNotifications.remove(peerIp);
    NotificationService.cancel(peerIp.hashCode.abs());
  }

  Future<void> sendSeen(DiscoveredDevice device) async {
    final socket = await _getOrConnect(device);
    if (socket == null) return;
    try {
      socket.write('${jsonEncode({'type': 'seen'})}\n');
    } catch (_) {}
  }

  Future<void> _sendSeenToIp(String peerIp) async {
    final socket = _connections[peerIp];
    if (socket == null) return;
    try {
      socket.write('${jsonEncode({'type': 'seen'})}\n');
    } catch (_) {}
  }

  final Map<String, _FileBuffer> _fileBuffers = {};

  Future<void> sendTo(
    DiscoveredDevice device,
    String content,
    MessageType type,
  ) async {
    final socket = await _getOrConnect(device);
    if (socket == null) return;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: _myName,
      senderIp: _myIp,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      isMe: true,
    );
    await _persist(device.ip, msg);
    try {
      socket.write('${jsonEncode(msg.toJson())}\n');
      if (msg.type == MessageType.text || msg.type == MessageType.code) {
        _messageController.add(msg);
      } else {
        _fileController.add(msg);
      }
    } catch (_) {
      _connections.remove(device.ip);
    }
  }

  Future<void> sendFile(
    DiscoveredDevice device,
    String fileName,
    Uint8List bytes,
  ) async {
    final socket = await _getOrConnect(device);
    if (socket == null) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();
    const chunkSize = 16 * 1024;
    final savedPath = await StorageService.saveFile(fileName, bytes);
    final msg = ChatMessage(
      id: id,
      senderName: _myName,
      senderIp: _myIp,
      content: fileName,
      type: MessageType.file,
      timestamp: DateTime.now(),
      isMe: true,
      fileBytes: bytes,
      fileName: fileName,
      savedPath: savedPath,
    );
    await _persist(device.ip, msg);
    _fileController.add(msg);
    try {
      socket.write(
        '${jsonEncode({'type': 'file_start', 'id': id, 'senderName': _myName, 'senderIp': _myIp, 'fileName': fileName, 'totalSize': bytes.length, 'timestamp': timestamp})}\n',
      );
      int offset = 0;
      while (offset < bytes.length) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(offset, end);
        socket.write(
          '${jsonEncode({'type': 'file_chunk', 'data': base64Encode(chunk)})}\n',
        );
        offset = end;
        await Future.delayed(Duration.zero);
      }
      socket.write('${jsonEncode({'type': 'file_end'})}\n');
    } catch (_) {
      _connections.remove(device.ip);
    }
  }

  Future<Socket?> _getOrConnect(DiscoveredDevice device) async {
    Socket? socket = _connections[device.ip];
    if (socket != null) return socket;
    try {
      socket = await Socket.connect(
        device.ip,
        device.port,
        timeout: const Duration(seconds: 3),
      );
      _connections[device.ip] = socket;
      _listenOnSocket(socket, device.ip);
      return socket;
    } catch (_) {
      return null;
    }
  }

  void stop() {
    for (final s in _connections.values) {
      s.destroy();
    }
    _connections.clear();
    _server?.close();
    _server = null;
  }

  void dispose() {
    stop();
    db.close();
    _messageController.close();
    _fileController.close();
    _seenController.close();
  }
}

class _FileBuffer {
  final String id;
  final String senderName;
  final String fileName;
  final int totalSize;
  final String timestamp;
  final List<Uint8List> bytes = [];

  _FileBuffer({
    required this.id,
    required this.senderName,
    required this.fileName,
    required this.totalSize,
    required this.timestamp,
  });
}
