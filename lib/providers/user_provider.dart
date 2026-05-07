import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UserProvider extends ChangeNotifier {
  String _name = '';
  String _avatar = '';
  String _localIp = '';
  bool _isSetup = false;

  String get name => _name;
  String get avatar => _avatar;
  String get localIp => _localIp;
  bool get isSetup => _isSetup;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('user_name') ?? '';
    _avatar = prefs.getString('user_avatar') ?? '';
    _isSetup = _name.isNotEmpty;
    await _fetchLocalIp();
    notifyListeners();
  }

  Future<void> _fetchLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _localIp = addr.address;
            return;
          }
        }
      }
    } catch (_) {
      _localIp = '0.0.0.0';
    }
  }

  Future<String> getDefaultName() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        return d.model;
      } else if (Platform.isMacOS) {
        final d = await info.macOsInfo;
        return d.computerName;
      } else if (Platform.isWindows) {
        final d = await info.windowsInfo;
        return d.computerName;
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        return d.name;
      }
    } catch (_) {}
    return 'Unknown Device';
  }

  Future<void> saveName(String name) async {
    _name = name.trim();
    _isSetup = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _name);
    notifyListeners();
  }

  Future<void> saveAvatar(String emoji) async {
    _avatar = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', emoji);
    notifyListeners();
  }

  Future<void> clearName() async {
    _name = '';
    _isSetup = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    notifyListeners();
  }
}
