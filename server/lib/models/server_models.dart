enum DeviceTrust {
  known,
  unknown;

  static DeviceTrust fromString(String? raw) =>
      raw?.toLowerCase() == 'known' ? DeviceTrust.known : DeviceTrust.unknown;
}

class ServerDevice {
  final String mac;
  final String name;
  final String note;
  final String vendor;
  final String deviceType;
  final String ipAddress;
  final String ipv6Address;
  final bool active;
  final String linkType; // eth | wifi24 | wifi5 | wifi6 | guest
  final String interfaceName;
  final String parentNodeId; // LIVEBOX or Repeater MAC
  final int? rssi;
  final int? linkSpeedMbps;
  final int rxBytes;
  final int txBytes;
  final double rxBytesPerSec;
  final double txBytesPerSec;
  final DeviceTrust trust;
  final int firstSeenMs;
  final int lastSeenMs;
  final int lastChangedMs;

  const ServerDevice({
    required this.mac,
    required this.name,
    this.note = '',
    required this.vendor,
    required this.deviceType,
    required this.ipAddress,
    this.ipv6Address = '',
    required this.active,
    required this.linkType,
    required this.interfaceName,
    this.parentNodeId = 'LIVEBOX',
    this.rssi,
    this.linkSpeedMbps,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.rxBytesPerSec = 0,
    this.txBytesPerSec = 0,
    this.trust = DeviceTrust.unknown,
    required this.firstSeenMs,
    required this.lastSeenMs,
    required this.lastChangedMs,
  });

  bool get isWifi => linkType.startsWith('wifi') || linkType == 'guest' || rssi != null;
  bool get hasIp => ipAddress.trim().isNotEmpty;
  bool get isActiveWithIp => active && hasIp;
  double get totalBytesPerSec => rxBytesPerSec + txBytesPerSec;

  ServerDevice copyWith({
    String? name,
    String? note,
    String? vendor,
    String? deviceType,
    String? ipAddress,
    String? ipv6Address,
    bool? active,
    String? linkType,
    String? interfaceName,
    String? parentNodeId,
    int? rssi,
    int? linkSpeedMbps,
    int? rxBytes,
    int? txBytes,
    double? rxBytesPerSec,
    double? txBytesPerSec,
    DeviceTrust? trust,
    int? lastSeenMs,
    int? lastChangedMs,
  }) =>
      ServerDevice(
        mac: mac,
        name: name ?? this.name,
        note: note ?? this.note,
        vendor: vendor ?? this.vendor,
        deviceType: deviceType ?? this.deviceType,
        ipAddress: ipAddress ?? this.ipAddress,
        ipv6Address: ipv6Address ?? this.ipv6Address,
        active: active ?? this.active,
        linkType: linkType ?? this.linkType,
        interfaceName: interfaceName ?? this.interfaceName,
        parentNodeId: parentNodeId ?? this.parentNodeId,
        rssi: rssi ?? this.rssi,
        linkSpeedMbps: linkSpeedMbps ?? this.linkSpeedMbps,
        rxBytes: rxBytes ?? this.rxBytes,
        txBytes: txBytes ?? this.txBytes,
        rxBytesPerSec: rxBytesPerSec ?? this.rxBytesPerSec,
        txBytesPerSec: txBytesPerSec ?? this.txBytesPerSec,
        trust: trust ?? this.trust,
        firstSeenMs: firstSeenMs,
        lastSeenMs: lastSeenMs ?? this.lastSeenMs,
        lastChangedMs: lastChangedMs ?? this.lastChangedMs,
      );

  Map<String, dynamic> toJson() => {
        'mac': mac,
        'name': name,
        'note': note,
        'vendor': vendor,
        'deviceType': deviceType,
        'ipAddress': ipAddress,
        'ipv6Address': ipv6Address,
        'active': active,
        'isActiveWithIp': isActiveWithIp,
        'linkType': linkType,
        'interfaceName': interfaceName,
        'parentNodeId': parentNodeId,
        'rssi': rssi,
        'linkSpeedMbps': linkSpeedMbps,
        'rxBytes': rxBytes,
        'txBytes': txBytes,
        'rxBytesPerSec': rxBytesPerSec,
        'txBytesPerSec': txBytesPerSec,
        'trust': trust.name,
        'firstSeenMs': firstSeenMs,
        'lastSeenMs': lastSeenMs,
        'lastChangedMs': lastChangedMs,
      };
}

class PresenceSpan {
  final int startMs;
  final int endMs;
  final bool online;

  const PresenceSpan({
    required this.startMs,
    required this.endMs,
    required this.online,
  });

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'online': online,
      };
}

class BandwidthPoint {
  final int timestampMs;
  final double rxBytesPerSec;
  final double txBytesPerSec;
  final int rxBytes;
  final int txBytes;

  const BandwidthPoint({
    required this.timestampMs,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.rxBytes,
    required this.txBytes,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'rxBytesPerSec': rxBytesPerSec,
        'txBytesPerSec': txBytesPerSec,
        'rxBytes': rxBytes,
        'txBytes': txBytes,
      };
}

class MonitorEvent {
  final int id;
  final int timestampMs;
  final String deviceMac;
  final String deviceName;
  final String reason;
  final String summary;
  final String rawJson;

  const MonitorEvent({
    required this.id,
    required this.timestampMs,
    required this.deviceMac,
    required this.deviceName,
    required this.reason,
    required this.summary,
    required this.rawJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestampMs': timestampMs,
        'deviceMac': deviceMac,
        'deviceName': deviceName,
        'reason': reason,
        'summary': summary,
        'rawJson': rawJson,
      };
}

class LiveboxCredentials {
  final String url;
  final String username;
  final String password;
  final bool demoMode;

  const LiveboxCredentials({
    required this.url,
    this.username = 'admin',
    this.password = '',
    this.demoMode = false,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'demoMode': demoMode,
      };

  Map<String, dynamic> toRedactedJson() => {
        'url': url,
        'username': username,
        'hasPassword': password.isNotEmpty,
        'demoMode': demoMode,
      };

  factory LiveboxCredentials.fromJson(Map<String, dynamic> json) =>
      LiveboxCredentials(
        url: json['url']?.toString() ?? 'http://livebox.home/',
        username: json['username']?.toString() ?? 'admin',
        password: json['password']?.toString() ?? '',
        demoMode: json['demoMode'] == true,
      );
}

class SmtpConfig {
  final bool enabled;
  final String host;
  final int port;
  final bool useSsl;
  final bool allowInsecure;
  final String username;
  final String password;
  final String fromAddress;
  final String toAddresses; // comma-separated recipients

  const SmtpConfig({
    this.enabled = false,
    this.host = '',
    this.port = 587,
    this.useSsl = false,
    this.allowInsecure = false,
    this.username = '',
    this.password = '',
    this.fromAddress = '',
    this.toAddresses = '',
  });

  List<String> get recipientList => toAddresses
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.contains('@'))
      .toList();

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'host': host,
        'port': port,
        'useSsl': useSsl,
        'allowInsecure': allowInsecure,
        'username': username,
        'password': password,
        'fromAddress': fromAddress,
        'toAddresses': toAddresses,
      };

  Map<String, dynamic> toRedactedJson() => {
        'enabled': enabled,
        'host': host,
        'port': port,
        'useSsl': useSsl,
        'allowInsecure': allowInsecure,
        'username': username,
        'hasPassword': password.isNotEmpty,
        'fromAddress': fromAddress,
        'toAddresses': toAddresses,
      };

  factory SmtpConfig.fromJson(Map<String, dynamic> json) => SmtpConfig(
        enabled: json['enabled'] == true,
        host: json['host']?.toString() ?? '',
        port: (json['port'] as num?)?.toInt() ?? 587,
        useSsl: json['useSsl'] == true,
        allowInsecure: json['allowInsecure'] == true,
        username: json['username']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        fromAddress: json['fromAddress']?.toString() ?? '',
        toAddresses: json['toAddresses']?.toString() ?? '',
      );
}
