class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  String get id => '$ip:$port';

  DiscoveredDevice copyWith({DateTime? lastSeen}) {
    return DiscoveredDevice(
      name: name,
      ip: ip,
      port: port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'port': port,
      };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      name: json['name'],
      ip: json['ip'],
      port: json['port'],
      lastSeen: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice && other.ip == ip && other.port == port;

  @override
  int get hashCode => Object.hash(ip, port);
}
