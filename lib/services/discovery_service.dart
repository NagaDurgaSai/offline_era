import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device.dart';

class DiscoveryService {
  static const int discoveryPort = 45678;
  static const int chatPort = 45679;
  static const Duration broadcastInterval = Duration(seconds: 3);
  static const Duration deviceTimeout = Duration(seconds: 12);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, DiscoveredDevice> _devices = {};
  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  List<DiscoveredDevice> get devices => _devices.values.toList();

  String _myName = '';
  String _myIp = '';

  Future<void> start(String name, String myIp) async {
    _myName = name;
    _myIp = myIp;

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
          _devices[device.ip] = device;
          _devicesController.add(devices);
        } catch (_) {}
      }
    });

    _broadcastTimer =
        Timer.periodic(broadcastInterval, (_) => _broadcast());
    _cleanupTimer =
        Timer.periodic(deviceTimeout, (_) => _cleanup());
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
    _devices.removeWhere(
        (_, d) => now.difference(d.lastSeen) > deviceTimeout + broadcastInterval);
    _devicesController.add(devices);
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
  }
}
