class HotspotInfo {
  final String ssid;
  final String password;
  final String ipAddress;
  final int port;
  final String serverPath;

  HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ipAddress,
    required this.port,
    required this.serverPath,
  });

  /// JSON에서 HotspotInfo 객체로 변환
  factory HotspotInfo.fromJson(Map<String, dynamic> json) {
    final port = json['port'] != null ? int.tryParse(json['port'].toString()) ?? 8080 : 8080;
    final ipAddress = json['ipAddress'];
    return HotspotInfo(
      ssid: json['ssid'],
      password: json['password'],
      ipAddress: ipAddress,
      port: port,
      serverPath: 'http://$ipAddress:$port',
    );
  }

  /// HotspotInfo 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'ipAddress': ipAddress,
      if (port != null) 'port': port,
    };
  }

  @override
  String toString() =>
      'HotspotInfo(SSID: $ssid, Password: $password, IP: $ipAddress${port !=
          null ? ', Port: $port' : ''})';
}
