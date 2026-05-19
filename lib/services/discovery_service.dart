import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import '../models/device.dart';
import '../services/database.dart';

class DiscoveryService {
  static const int discoveryPort = 45678;
  static const int chatPort = 45679;
  static const Duration broadcastInterval = Duration(seconds: 1);
  static const Duration deviceTimeout = Duration(seconds: 2);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, DiscoveredDevice> _onlineDevices = {};
  final Map<String, DiscoveredDevice> _allDevices = {};
  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  final _onlineController = StreamController<Set<String>>.broadcast();

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  Stream<Set<String>> get onlineStream => _onlineController.stream;

  List<DiscoveredDevice> get devices => _allDevices.values.toList()
    ..sort((a, b) {
      final aOnline = _onlineDevices.containsKey(a.ip) ? 0 : 1;
      final bOnline = _onlineDevices.containsKey(b.ip) ? 0 : 1;
      return aOnline.compareTo(bOnline);
    });

  Set<String> get onlineIps => _onlineDevices.values.map((d) => d.ip).toSet();

  final Set<String> _deletedIps = {};
  String _myName = '';
  String _myAvatar = '';
  String _myIp = '';
  String _myDeviceId = '';
  AppDatabase? _db;

  Future<void> start(String name, String avatar, String myIp, AppDatabase db, String deviceId) async {
    _myName = name;
    _myAvatar = avatar;
    _myIp = myIp;
    _myDeviceId = deviceId;
    _db = db;

    // load known devices from db
    final known = await db.getAllKnownDevices();
    for (final d in known) {
      if (_deletedIps.contains(d.ip)) continue;
      final key = d.deviceId.isNotEmpty ? d.deviceId : d.ip;
      _allDevices[key] = DiscoveredDevice(
        name: d.name,
        avatar: '',
        ip: d.ip,
        port: d.port,
        lastSeen: DateTime.parse(d.lastSeen),
        deviceId: d.deviceId,
      );
    }
    _devicesController.add(devices);

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg == null) return;
        try {
          final data = jsonDecode(utf8.decode(dg.data));
          final device = DiscoveredDevice.fromJson(data);
          if (device.ip == _myIp) return;

          // Ignore broadcasts from manually deleted devices
          if (_deletedIps.contains(device.ip)) return;

          final key = device.deviceId.isNotEmpty ? device.deviceId : device.ip;

          // If same IP exists under a different deviceId, remove the stale entry
          // This happens when app is reinstalled (new deviceId, same IP)
          if (device.deviceId.isNotEmpty) {
            final stale = _allDevices.entries.where((e) =>
              e.key != key &&
              e.value.ip == device.ip
            ).toList();
            for (final s in stale) {
              _allDevices.remove(s.key);
              _onlineDevices.remove(s.key);
              // remove stale db row by old deviceId
              if (s.value.deviceId.isNotEmpty) {
                _db?.deleteKnownDeviceByDeviceId(s.value.deviceId);
              }
            }
          }

          _onlineDevices[key] = device;
          _allDevices[key] = device;

          // persist to db — upsert by IP so IP updates don't create new rows
          _db?.upsertKnownDevice(KnownDevicesCompanion(
            ip: Value(device.ip),
            name: Value(device.name),
            port: Value(device.port),
            lastSeen: Value(device.lastSeen.toIso8601String()),
            deviceId: Value(device.deviceId),
          ));

          _devicesController.add(devices);
          _onlineController.add(onlineIps);
        } catch (_) {}
      }
    });

    _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _broadcast());
    _cleanupTimer = Timer.periodic(deviceTimeout, (_) => _cleanup());
    _broadcast();
  }

  void updateProfile(String newName, String newAvatar) {
    _myName = newName;
    _myAvatar = newAvatar;
    _broadcast();
  }

  void _broadcast() {
    if (_socket == null) return;
    final payload = jsonEncode({
      'name': _myName,
      'avatar': _myAvatar,
      'ip': _myIp,
      'port': chatPort,
      'deviceId': _myDeviceId,
    });
    final data = utf8.encode(payload);
    _socket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
  }

  void _cleanup() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final entry in _onlineDevices.entries) {
      if (now.difference(entry.value.lastSeen) > deviceTimeout + broadcastInterval) {
        toRemove.add(entry.key); // key is deviceId or ip
      }
    }
    if (toRemove.isNotEmpty) {
      for (final ip in toRemove) _onlineDevices.remove(ip);
      _devicesController.add(devices);
      _onlineController.add(onlineIps);
    }
  }

  void stop() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  /// Permanently remove a device — won't reappear from DB or broadcast
  void removeDevice(String ip) {
    _deletedIps.add(ip);
    // Remove from in-memory maps
    _allDevices.removeWhere((_, d) => d.ip == ip);
    _onlineDevices.removeWhere((_, d) => d.ip == ip);
    _devicesController.add(devices);
    _onlineController.add(onlineIps);
  }

  /// Manually connect to a device by IP.
  /// Sends our identity via UDP directly to that IP (bypasses subnet broadcast).
  /// Returns the device name if already known, IP string if new, null on failure.
  Future<String?> manualConnect(String ip) async {
    try {
      // 1. Verify the device is reachable on the chat port
      final socket = await Socket.connect(
        ip, chatPort,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();

      // 2. Send our identity packet directly to their UDP port
      //    This is how discovery works — we just aim it at a specific IP
      //    instead of the broadcast address. They will receive it and add us.
      if (_socket != null) {
        final payload = jsonEncode({
          'name': _myName,
          'avatar': _myAvatar,
          'ip': _myIp,
          'port': chatPort,
          'deviceId': _myDeviceId,
        });
        final data = utf8.encode(payload);
        // Send several times to improve reliability
        for (int i = 0; i < 3; i++) {
          _socket!.send(data, InternetAddress(ip), discoveryPort);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // 3. If already known, mark online and return name
      final existing = _allDevices.values.where((d) => d.ip == ip).toList();
      if (existing.isNotEmpty) {
        final dev = existing.first;
        final key = dev.deviceId.isNotEmpty ? dev.deviceId : dev.ip;
        _onlineDevices[key] = dev.copyWith(lastSeen: DateTime.now());
        _devicesController.add(devices);
        _onlineController.add(onlineIps);
        return dev.name;
      }

      // 4. Unknown — add placeholder; their reply broadcast will fill real details
      final placeholder = DiscoveredDevice(
        name: ip,
        avatar: '',
        ip: ip,
        port: chatPort,
        lastSeen: DateTime.now(),
        deviceId: '',
      );
      _onlineDevices[ip] = placeholder;
      _allDevices[ip] = placeholder;
      _db?.upsertKnownDevice(KnownDevicesCompanion(
        ip: Value(ip),
        name: Value(ip),
        port: Value(chatPort),
        lastSeen: Value(DateTime.now().toIso8601String()),
        deviceId: const Value(''),
      ));
      _devicesController.add(devices);
      _onlineController.add(onlineIps);

      // 5. Wait up to 3s for them to reply with their real identity
      await Future.delayed(const Duration(seconds: 3));
      final updated = _allDevices.values.where((d) => d.ip == ip).toList();
      return updated.isNotEmpty ? updated.first.name : ip;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stop();
    _devicesController.close();
    _onlineController.close();
  }
}
