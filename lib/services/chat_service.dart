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
  final AppDatabase db = AppDatabase();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatMessage> get clipboardStream => _fileController.stream;
  Stream<ChatMessage> get fileStream => _fileController.stream;

  String _myName = '';
  String _myIp = '';
  bool isInChat = false;

  final Map<String, List<ChatMessage>> _cache = {};

  // file reassembly buffers per peer
  final Map<String, _FileBuffer> _fileBuffers = {};

  Future<List<ChatMessage>> historyFor(String peerIp) async {
    if (_cache.containsKey(peerIp)) return _cache[peerIp]!;
    final rows = await db.messagesForPeer(peerIp);
    final msgs = rows.map((r) => ChatMessage(
      id: r.id,
      senderName: r.senderName,
      senderIp: r.senderIp,
      content: r.content,
      type: MessageType.values.firstWhere((e) => e.name == r.type,
          orElse: () => MessageType.text),
      timestamp: DateTime.parse(r.timestamp),
      isMe: r.isMe,
      fileName: r.fileName,
      savedPath: r.savedPath,
      fileBytes: r.savedPath != null && File(r.savedPath!).existsSync()
          ? File(r.savedPath!).readAsBytesSync()
          : null,
    )).toList();
    _cache[peerIp] = msgs;
    return msgs;
  }

  Future<void> _persist(String peerIp, ChatMessage msg) async {
    _cache.putIfAbsent(peerIp, () => []);
    if (!_cache[peerIp]!.any((m) => m.id == msg.id)) {
      _cache[peerIp]!.add(msg);
    }
    await db.insertMessage(MessagesCompanion(
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
    ));
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
    // close old connection if exists
    if (_connections.containsKey(remoteIp)) {
      try { _connections[remoteIp]?.destroy(); } catch (_) {}
    }
    _connections[remoteIp] = socket;
    _listenOnSocket(socket, remoteIp);
  }

  void _listenOnSocket(Socket socket, String remoteIp) {
    // use raw byte framing: 4-byte big-endian length prefix + payload
    final lengthBuf = BytesBuilder();
    int? expectedLen;
    final payloadBuf = BytesBuilder();

    socket.listen(
      (Uint8List data) {
        var offset = 0;
        while (offset < data.length) {
          if (expectedLen == null) {
            // reading 4-byte length header
            final remaining = 4 - lengthBuf.length;
            final take = (data.length - offset).clamp(0, remaining);
            lengthBuf.add(data.sublist(offset, offset + take));
            offset += take;
            if (lengthBuf.length == 4) {
              final lb = lengthBuf.toBytes();
              expectedLen = (lb[0] << 24) | (lb[1] << 16) | (lb[2] << 8) | lb[3];
              lengthBuf.clear();
            }
          } else {
            final remaining = expectedLen! - payloadBuf.length;
            final take = (data.length - offset).clamp(0, remaining);
            payloadBuf.add(data.sublist(offset, offset + take));
            offset += take;
            if (payloadBuf.length == expectedLen!) {
              final bytes = payloadBuf.toBytes();
              payloadBuf.clear();
              expectedLen = null;
              _handlePacket(bytes, remoteIp);
            }
          }
        }
      },
      onDone: () {
        _connections.remove(remoteIp);
        _fileBuffers.remove(remoteIp);
      },
      onError: (_) {
        _connections.remove(remoteIp);
        _fileBuffers.remove(remoteIp);
      },
    );
  }

  void _handlePacket(Uint8List bytes, String remoteIp) async {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      final msgType = json['type'] as String;

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
        final allBytes = Uint8List.fromList(buf.bytes.expand((e) => e).toList());
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
        if (!isInChat) {
          NotificationService.showFile(buf.senderName, buf.fileName);
        }
        return;
      }

      // regular text/code message
      final msg = ChatMessage.fromJson(json, _myIp);
      await _persist(remoteIp, msg);
      if (msg.type == MessageType.text || msg.type == MessageType.code) {
        _messageController.add(msg);
        if (!isInChat) {
          NotificationService.showMessage(
            msg.senderName,
            msg.type == MessageType.code ? '📎 code snippet' : msg.content,
          );
        }
      } else {
        _fileController.add(msg);
      }
    } catch (_) {}
  }

  void _sendPacket(Socket socket, Map<String, dynamic> json) {
    final payload = utf8.encode(jsonEncode(json));
    final len = payload.length;
    final header = Uint8List(4);
    header[0] = (len >> 24) & 0xFF;
    header[1] = (len >> 16) & 0xFF;
    header[2] = (len >> 8) & 0xFF;
    header[3] = len & 0xFF;
    socket.add(header);
    socket.add(payload);
  }

  Future<void> sendTo(
      DiscoveredDevice device, String content, MessageType type) async {
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
      _sendPacket(socket, msg.toJson());
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
      DiscoveredDevice device, String fileName, Uint8List bytes) async {
    final socket = await _getOrConnect(device);
    if (socket == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();
    const chunkSize = 16 * 1024; // 16KB chunks

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
      // send start
      _sendPacket(socket, {
        'type': 'file_start',
        'id': id,
        'senderName': _myName,
        'senderIp': _myIp,
        'fileName': fileName,
        'totalSize': bytes.length,
        'timestamp': timestamp,
      });

      // send chunks
      int offset = 0;
      while (offset < bytes.length) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(offset, end);
        _sendPacket(socket, {
          'type': 'file_chunk',
          'data': base64Encode(chunk),
        });
        offset = end;
        // small yield to not block
        await Future.delayed(Duration.zero);
      }

      // send end
      _sendPacket(socket, {'type': 'file_end'});
    } catch (_) {
      _connections.remove(device.ip);
    }
  }

  Future<Socket?> _getOrConnect(DiscoveredDevice device) async {
    Socket? socket = _connections[device.ip];
    if (socket != null) return socket;
    try {
      socket = await Socket.connect(device.ip, device.port,
          timeout: const Duration(seconds: 3));
      _connections[device.ip] = socket;
      _listenOnSocket(socket, device.ip);
      return socket;
    } catch (_) {
      return null;
    }
  }

  void stop() {
    for (final s in _connections.values) s.destroy();
    _connections.clear();
    _server?.close();
    _server = null;
  }

  void dispose() {
    stop();
    db.close();
    _messageController.close();
    _fileController.close();
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
