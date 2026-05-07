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
  static const Duration deviceTimeout = Duration(seconds: 5);

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

  Set<String> get onlineIps => _onlineDevices.keys.toSet();

  String _myName = '';
  String _myIp = '';
  AppDatabase? _db;

  Future<void> start(String name, String myIp, AppDatabase db) async {
    _myName = name;
    _myIp = myIp;
    _db = db;

    // load known devices from db
    final known = await db.getAllKnownDevices();
    for (final d in known) {
      _allDevices[d.ip] = DiscoveredDevice(
        name: d.name,
        ip: d.ip,
        port: d.port,
        lastSeen: DateTime.parse(d.lastSeen),
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

          _onlineDevices[device.ip] = device;
          _allDevices[device.ip] = device;

          // persist to db
          _db?.upsertKnownDevice(KnownDevicesCompanion(
            ip: Value(device.ip),
            name: Value(device.name),
            port: Value(device.port),
            lastSeen: Value(device.lastSeen.toIso8601String()),
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

  void updateName(String newName) {
    _myName = newName;
    _broadcast();
  }

  void _broadcast() {
    if (_socket == null) return;
    final payload = jsonEncode({
      'name': _myName,
      'ip': _myIp,
      'port': chatPort,
    });
    final data = utf8.encode(payload);
    _socket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
  }

  void _cleanup() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final entry in _onlineDevices.entries) {
      if (now.difference(entry.value.lastSeen) > deviceTimeout + broadcastInterval) {
        toRemove.add(entry.key);
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

  void dispose() {
    stop();
    _devicesController.close();
    _onlineController.close();
  }
}
