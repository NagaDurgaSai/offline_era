import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../services/notification_service.dart';
import 'discovery_service.dart';

class ChatService {
  ServerSocket? _server;
  final Map<String, Socket> _connections = {};
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _fileController = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatMessage> get clipboardStream => _fileController.stream;
  Stream<ChatMessage> get fileStream => _fileController.stream;

  String _myName = '';
  String _myIp = '';
  bool isInChat = false;

  final Map<String, List<ChatMessage>> _history = {};
  List<ChatMessage> historyFor(String peerIp) => _history[peerIp] ?? [];

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

  void updateName(String name) {
    _myName = name;
  }

  void _handleIncoming(Socket socket) {
    final remoteIp = socket.remoteAddress.address;
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
          _handleChunk(chunk, remoteIp);
        }
        if (lines.last.isNotEmpty) buffer.write(lines.last);
      },
      onDone: () => _connections.remove(remoteIp),
      onError: (_) => _connections.remove(remoteIp),
    );
  }

  void _handleChunk(String chunk, String remoteIp) {
    try {
      final json = jsonDecode(chunk);

      if (json['type'] == 'file') {
        final fileName = json['fileName'] as String;
        final fileData = base64Decode(json['fileData'] as String);
        _saveFile(fileName, fileData).then((savedPath) {
          final msg = ChatMessage(
            id: json['id'],
            senderName: json['senderName'],
            senderIp: remoteIp,
            content: fileName,
            type: MessageType.file,
            timestamp: DateTime.parse(json['timestamp']),
            isMe: false,
            fileBytes: fileData,
            fileName: fileName,
            savedPath: savedPath,
          );
          _history.putIfAbsent(remoteIp, () => []).add(msg);
          _fileController.add(msg);
          if (!isInChat) {
            NotificationService.showFile(json['senderName'], fileName);
          }
        });
        return;
      }

      if (json['type'] == 'name_update') {
        // handled by discovery, ignore here
        return;
      }

      final msg = ChatMessage.fromJson(json, _myIp);
      _history.putIfAbsent(remoteIp, () => []).add(msg);

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

  Future<String> _saveFile(String fileName, Uint8List bytes) async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
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
    _history.putIfAbsent(device.ip, () => []).add(msg);

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
      DiscoveredDevice device, String fileName, Uint8List bytes) async {
    final socket = await _getOrConnect(device);
    if (socket == null) return;

    final payload = jsonEncode({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderName': _myName,
      'senderIp': _myIp,
      'type': 'file',
      'fileName': fileName,
      'fileData': base64Encode(bytes),
      'timestamp': DateTime.now().toIso8601String(),
    });

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: _myName,
      senderIp: _myIp,
      content: fileName,
      type: MessageType.file,
      timestamp: DateTime.now(),
      isMe: true,
      fileBytes: bytes,
      fileName: fileName,
    );
    _history.putIfAbsent(device.ip, () => []).add(msg);

    try {
      socket.write('$payload\n');
      _fileController.add(msg);
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
    _messageController.close();
    _fileController.close();
  }
}
