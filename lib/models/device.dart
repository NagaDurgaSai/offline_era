class DiscoveredDevice {
  final String name;
  final String avatar;
  final String ip;
  final int port;
  final DateTime lastSeen;
  final String deviceId;

  DiscoveredDevice({
    required this.name,
    this.avatar = '',
    required this.ip,
    required this.port,
    required this.lastSeen,
    this.deviceId = '',
  });

  String get id => deviceId.isNotEmpty ? deviceId : '$ip:$port';

  DiscoveredDevice copyWith({String? name, String? avatar, String? ip, int? port, DateTime? lastSeen, String? deviceId}) {
    return DiscoveredDevice(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatar': avatar,
        'ip': ip,
        'port': port,
        'deviceId': deviceId,
      };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      name: json['name'],
      avatar: (json['avatar'] ?? '').toString(),
      ip: json['ip'],
      port: json['port'],
      lastSeen: DateTime.now(),
      deviceId: (json['deviceId'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice &&
      (deviceId.isNotEmpty && other.deviceId.isNotEmpty
          ? other.deviceId == deviceId
          : other.ip == ip && other.port == port);

  @override
  int get hashCode =>
      deviceId.isNotEmpty ? deviceId.hashCode : Object.hash(ip, port);

}
