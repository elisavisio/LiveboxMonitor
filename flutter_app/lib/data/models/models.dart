import 'dart:convert';

/// Saved connection profile for a Livebox router.
class ConnectionProfile {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final bool savePassword;

  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.url,
    this.username = 'admin',
    this.password = '',
    this.savePassword = true,
  });

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? url,
    String? username,
    String? password,
    bool? savePassword,
  }) =>
      ConnectionProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        savePassword: savePassword ?? this.savePassword,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
        'password': savePassword ? password : '',
        'savePassword': savePassword,
      };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) =>
      ConnectionProfile(
        id: json['id']?.toString() ?? 'default',
        name: json['name']?.toString() ?? 'Home Livebox',
        url: json['url']?.toString() ?? 'http://livebox.home/',
        username: json['username']?.toString() ?? 'admin',
        password: json['password']?.toString() ?? '',
        savePassword: json['savePassword'] as bool? ?? true,
      );

  static String encodeList(List<ConnectionProfile> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ConnectionProfile> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConnectionProfile.fromJson)
          .toList();
    }
    return [];
  }
}

/// Core Livebox system, WAN, ONT, LAN, Wi-Fi, IPTV, VoIP, USB telemetry.
class LiveboxInfo {
  final String modelName; // e.g. Livebox 7 W7
  final String productClass;
  final String manufacturer;
  final String serialNumber;
  final String hardwareVersion;
  final String softwareVersion;
  final String macAddress;
  final int uptimeSeconds;
  final int memoryTotalKb;
  final int memoryFreeKb;
  final String linkType; // gpon, xgpon, dsl, eth
  final String linkState; // up / down
  final String wanStatus;
  final String wanIpv4;
  final String wanIpv6;
  final String wanIpv6Prefix;
  final String wanGateway;
  final List<String> dnsServers;
  final int maxDownBitrateMbps;
  final int maxUpBitrateMbps;
  // ONT / Fiber optical metrics
  final String? ontModel;
  final String? ontSerial;
  final double? opticalRxPowerDbm;
  final double? opticalTxPowerDbm;
  final double? opticalTempC;
  final double? opticalVoltageV;
  // LAN
  final String lanIp;
  final String lanMask;
  // Status flags
  final bool wifiEnabled;
  final bool guestWifiEnabled;
  final bool wifiSchedulerEnabled;
  final bool voipRegistered;
  final String voipNumber;
  final bool iptvEnabled;
  final int usbDeviceCount;
  // Screen & LEDs
  final int orangeLedLevel;
  final bool showWifiPasswordOnScreen;

  const LiveboxInfo({
    required this.modelName,
    required this.productClass,
    required this.manufacturer,
    required this.serialNumber,
    required this.hardwareVersion,
    required this.softwareVersion,
    required this.macAddress,
    required this.uptimeSeconds,
    required this.memoryTotalKb,
    required this.memoryFreeKb,
    required this.linkType,
    required this.linkState,
    required this.wanStatus,
    required this.wanIpv4,
    required this.wanIpv6,
    required this.wanIpv6Prefix,
    required this.wanGateway,
    required this.dnsServers,
    required this.maxDownBitrateMbps,
    required this.maxUpBitrateMbps,
    this.ontModel,
    this.ontSerial,
    this.opticalRxPowerDbm,
    this.opticalTxPowerDbm,
    this.opticalTempC,
    this.opticalVoltageV,
    required this.lanIp,
    required this.lanMask,
    required this.wifiEnabled,
    required this.guestWifiEnabled,
    required this.wifiSchedulerEnabled,
    required this.voipRegistered,
    required this.voipNumber,
    required this.iptvEnabled,
    required this.usbDeviceCount,
    this.orangeLedLevel = 255,
    this.showWifiPasswordOnScreen = false,
  });

  double get memoryUsedPercent => memoryTotalKb > 0
      ? ((memoryTotalKb - memoryFreeKb) / memoryTotalKb).clamp(0.0, 1.0)
      : 0.0;

  LiveboxInfo copyWith({
    int? uptimeSeconds,
    bool? wifiEnabled,
    bool? guestWifiEnabled,
    bool? wifiSchedulerEnabled,
    int? orangeLedLevel,
    bool? showWifiPasswordOnScreen,
  }) =>
      LiveboxInfo(
        modelName: modelName,
        productClass: productClass,
        manufacturer: manufacturer,
        serialNumber: serialNumber,
        hardwareVersion: hardwareVersion,
        softwareVersion: softwareVersion,
        macAddress: macAddress,
        uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
        memoryTotalKb: memoryTotalKb,
        memoryFreeKb: memoryFreeKb,
        linkType: linkType,
        linkState: linkState,
        wanStatus: wanStatus,
        wanIpv4: wanIpv4,
        wanIpv6: wanIpv6,
        wanIpv6Prefix: wanIpv6Prefix,
        wanGateway: wanGateway,
        dnsServers: dnsServers,
        maxDownBitrateMbps: maxDownBitrateMbps,
        maxUpBitrateMbps: maxUpBitrateMbps,
        ontModel: ontModel,
        ontSerial: ontSerial,
        opticalRxPowerDbm: opticalRxPowerDbm,
        opticalTxPowerDbm: opticalTxPowerDbm,
        opticalTempC: opticalTempC,
        opticalVoltageV: opticalVoltageV,
        lanIp: lanIp,
        lanMask: lanMask,
        wifiEnabled: wifiEnabled ?? this.wifiEnabled,
        guestWifiEnabled: guestWifiEnabled ?? this.guestWifiEnabled,
        wifiSchedulerEnabled: wifiSchedulerEnabled ?? this.wifiSchedulerEnabled,
        voipRegistered: voipRegistered,
        voipNumber: voipNumber,
        iptvEnabled: iptvEnabled,
        usbDeviceCount: usbDeviceCount,
        orangeLedLevel: orangeLedLevel ?? this.orangeLedLevel,
        showWifiPasswordOnScreen:
            showWifiPasswordOnScreen ?? this.showWifiPasswordOnScreen,
      );
}

/// Network interface (WAN, Eth ports, Wi-Fi 2.4/5/6 GHz, Guest).
class NetworkInterfaceInfo {
  final String key;
  final String name;
  final String type; // wan, lan, eth, wif, gwi
  final bool enabled;
  final bool up;
  final int speedMbps;
  final int? channel;
  final String? band; // 2.4GHz, 5GHz, 6GHz
  final String? ssid;
  final String? securityMode;
  final int rxBytes;
  final int txBytes;
  final double rxBytesPerSec;
  final double txBytesPerSec;

  const NetworkInterfaceInfo({
    required this.key,
    required this.name,
    required this.type,
    required this.enabled,
    required this.up,
    required this.speedMbps,
    this.channel,
    this.band,
    this.ssid,
    this.securityMode,
    required this.rxBytes,
    required this.txBytes,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
  });

  NetworkInterfaceInfo copyWith({
    bool? enabled,
    bool? up,
    int? rxBytes,
    int? txBytes,
    double? rxBytesPerSec,
    double? txBytesPerSec,
  }) =>
      NetworkInterfaceInfo(
        key: key,
        name: name,
        type: type,
        enabled: enabled ?? this.enabled,
        up: up ?? this.up,
        speedMbps: speedMbps,
        channel: channel,
        band: band,
        ssid: ssid,
        securityMode: securityMode,
        rxBytes: rxBytes ?? this.rxBytes,
        txBytes: txBytes ?? this.txBytes,
        rxBytesPerSec: rxBytesPerSec ?? this.rxBytesPerSec,
        txBytesPerSec: txBytesPerSec ?? this.txBytesPerSec,
      );
}

/// Connected or remembered LAN/Wi-Fi device.
class NetworkDevice {
  final String key; // MAC address uppercase
  final String name;
  final String liveboxName;
  final String dnsName;
  final String deviceType;
  final String vendor;
  final String ipAddress;
  final String ipv6Address;
  final bool active;
  final bool blocked;
  final bool staticIp;
  final String interfaceKey;
  final String interfaceName;
  final String linkType; // eth, wifi24, wifi5, wifi6, guest, repeater
  final int? rssi;
  final int? linkSpeedMbps;
  final int rxBytes;
  final int txBytes;
  final double rxBytesPerSec;
  final double txBytesPerSec;
  final DateTime? firstSeen;
  final DateTime? lastChanged;
  final List<String> tags;

  const NetworkDevice({
    required this.key,
    required this.name,
    required this.liveboxName,
    required this.dnsName,
    required this.deviceType,
    required this.vendor,
    required this.ipAddress,
    required this.ipv6Address,
    required this.active,
    required this.blocked,
    required this.staticIp,
    required this.interfaceKey,
    required this.interfaceName,
    required this.linkType,
    this.rssi,
    this.linkSpeedMbps,
    required this.rxBytes,
    required this.txBytes,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    this.firstSeen,
    this.lastChanged,
    this.tags = const [],
  });

  bool get isWifi =>
      linkType.startsWith('wifi') || linkType == 'guest' || rssi != null;

  NetworkDevice copyWith({
    String? name,
    String? liveboxName,
    String? deviceType,
    bool? active,
    bool? blocked,
    bool? staticIp,
    String? ipAddress,
    int? rssi,
    int? rxBytes,
    int? txBytes,
    double? rxBytesPerSec,
    double? txBytesPerSec,
    DateTime? lastChanged,
  }) =>
      NetworkDevice(
        key: key,
        name: name ?? this.name,
        liveboxName: liveboxName ?? this.liveboxName,
        dnsName: dnsName,
        deviceType: deviceType ?? this.deviceType,
        vendor: vendor,
        ipAddress: ipAddress ?? this.ipAddress,
        ipv6Address: ipv6Address,
        active: active ?? this.active,
        blocked: blocked ?? this.blocked,
        staticIp: staticIp ?? this.staticIp,
        interfaceKey: interfaceKey,
        interfaceName: interfaceName,
        linkType: linkType,
        rssi: rssi ?? this.rssi,
        linkSpeedMbps: linkSpeedMbps,
        rxBytes: rxBytes ?? this.rxBytes,
        txBytes: txBytes ?? this.txBytes,
        rxBytesPerSec: rxBytesPerSec ?? this.rxBytesPerSec,
        txBytesPerSec: txBytesPerSec ?? this.txBytesPerSec,
        firstSeen: firstSeen,
        lastChanged: lastChanged ?? this.lastChanged,
        tags: tags,
      );
}

/// Real-time traffic sample for graphs.
class TrafficSample {
  final DateTime timestamp;
  final double downMbps;
  final double upMbps;

  const TrafficSample({
    required this.timestamp,
    required this.downMbps,
    required this.upMbps,
  });
}

/// Livebox sysbus event entry.
class LiveboxEvent {
  final String id;
  final DateTime timestamp;
  final String deviceKey;
  final String deviceName;
  final String reason; // e.g. Active, Inactive, IP Address, Link Change, Firewall
  final String summary;
  final Map<String, dynamic> rawPayload;

  const LiveboxEvent({
    required this.id,
    required this.timestamp,
    required this.deviceKey,
    required this.deviceName,
    required this.reason,
    required this.summary,
    required this.rawPayload,
  });
}

/// DHCP Server config, leases, and static bindings.
class DhcpConfig {
  final bool enabled;
  final String lanIp;
  final String subnetMask;
  final String minAddress;
  final String maxAddress;
  final int leaseTimeSeconds;
  final bool dhcpv6Enabled;
  final String ipv6Prefix;

  const DhcpConfig({
    required this.enabled,
    required this.lanIp,
    required this.subnetMask,
    required this.minAddress,
    required this.maxAddress,
    required this.leaseTimeSeconds,
    required this.dhcpv6Enabled,
    required this.ipv6Prefix,
  });

  DhcpConfig copyWith({
    bool? enabled,
    String? lanIp,
    String? subnetMask,
    String? minAddress,
    String? maxAddress,
    int? leaseTimeSeconds,
    bool? dhcpv6Enabled,
  }) =>
      DhcpConfig(
        enabled: enabled ?? this.enabled,
        lanIp: lanIp ?? this.lanIp,
        subnetMask: subnetMask ?? this.subnetMask,
        minAddress: minAddress ?? this.minAddress,
        maxAddress: maxAddress ?? this.maxAddress,
        leaseTimeSeconds: leaseTimeSeconds ?? this.leaseTimeSeconds,
        dhcpv6Enabled: dhcpv6Enabled ?? this.dhcpv6Enabled,
        ipv6Prefix: ipv6Prefix,
      );
}

class DhcpBinding {
  final String macAddress;
  final String ipAddress;
  final String deviceName;
  final bool isStatic;
  final bool active;
  final String? domain;

  const DhcpBinding({
    required this.macAddress,
    required this.ipAddress,
    required this.deviceName,
    required this.isStatic,
    required this.active,
    this.domain,
  });
}

/// NAT/PAT Port forwarding rule.
class NatPatRule {
  final String id;
  final String name;
  final String type; // IPv4, IPv6, UPnP
  final bool enabled;
  final String protocol; // TCP, UDP, TCP/UDP
  final String externalPort;
  final String internalPort;
  final String destinationIp;
  final String externalIps;
  final String description;

  const NatPatRule({
    required this.id,
    required this.name,
    this.type = 'IPv4',
    required this.enabled,
    required this.protocol,
    required this.externalPort,
    required this.internalPort,
    required this.destinationIp,
    this.externalIps = 'All',
    this.description = '',
  });

  NatPatRule copyWith({
    bool? enabled,
    String? name,
    String? protocol,
    String? externalPort,
    String? internalPort,
    String? destinationIp,
    String? externalIps,
    String? description,
  }) =>
      NatPatRule(
        id: id,
        name: name ?? this.name,
        type: type,
        enabled: enabled ?? this.enabled,
        protocol: protocol ?? this.protocol,
        externalPort: externalPort ?? this.externalPort,
        internalPort: internalPort ?? this.internalPort,
        destinationIp: destinationIp ?? this.destinationIp,
        externalIps: externalIps ?? this.externalIps,
        description: description ?? this.description,
      );
}

class PtfRule {
  final String id;
  final String name;
  final bool enabled;
  final String protocol; // GRE, ESP, AH, ICMP, etc.
  final String destinationIp;
  final String externalIps;

  const PtfRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.protocol,
    required this.destinationIp,
    this.externalIps = 'All',
  });
}

class DmzConfig {
  final bool enabled;
  final String destinationIp;
  final String externalIps;

  const DmzConfig({
    required this.enabled,
    required this.destinationIp,
    this.externalIps = '',
  });
}

/// Firewall state and custom rules.
class FirewallRule {
  final String id;
  final bool enabled;
  final bool isIpv6;
  final String action; // Accept / Drop
  final String protocol; // TCP, UDP, ICMP, All
  final String sourcePrefix;
  final String sourcePort;
  final String destinationPrefix;
  final String destinationPort;
  final String description;

  const FirewallRule({
    required this.id,
    required this.enabled,
    required this.isIpv6,
    required this.action,
    required this.protocol,
    required this.sourcePrefix,
    required this.sourcePort,
    required this.destinationPrefix,
    required this.destinationPort,
    required this.description,
  });

  FirewallRule copyWith({bool? enabled}) => FirewallRule(
        id: id,
        enabled: enabled ?? this.enabled,
        isIpv6: isIpv6,
        action: action,
        protocol: protocol,
        sourcePrefix: sourcePrefix,
        sourcePort: sourcePort,
        destinationPrefix: destinationPrefix,
        destinationPort: destinationPort,
        description: description,
      );
}

class FirewallState {
  final String ipv4Level; // Low, Medium, High, Custom
  final String ipv6Level; // Low, Medium, High, Custom
  final bool respondToPingIpv4;
  final bool respondToPingIpv6;
  final List<FirewallRule> rules;

  const FirewallState({
    required this.ipv4Level,
    required this.ipv6Level,
    required this.respondToPingIpv4,
    required this.respondToPingIpv6,
    required this.rules,
  });

  FirewallState copyWith({
    String? ipv4Level,
    String? ipv6Level,
    bool? respondToPingIpv4,
    bool? respondToPingIpv6,
    List<FirewallRule>? rules,
  }) =>
      FirewallState(
        ipv4Level: ipv4Level ?? this.ipv4Level,
        ipv6Level: ipv6Level ?? this.ipv6Level,
        respondToPingIpv4: respondToPingIpv4 ?? this.respondToPingIpv4,
        respondToPingIpv6: respondToPingIpv6 ?? this.respondToPingIpv6,
        rules: rules ?? this.rules,
      );
}

/// VoIP Call log & Contact.
enum CallType { incoming, outgoing, missed, failed }

class PhoneCallEntry {
  final String id;
  final CallType type;
  final DateTime timestamp;
  final String number;
  final String contactName;
  final int durationSeconds;
  final bool isSpam;

  const PhoneCallEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.number,
    required this.contactName,
    required this.durationSeconds,
    this.isSpam = false,
  });
}

class PhoneContact {
  final String id;
  final String firstName;
  final String lastName;
  final String cellNumber;
  final String homeNumber;
  final String workNumber;
  final String ringtone;

  const PhoneContact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.cellNumber = '',
    this.homeNumber = '',
    this.workNumber = '',
    this.ringtone = '1',
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// Orange Wi-Fi Repeater.
class RepeaterInfo {
  final String key; // MAC
  final String name;
  final String model;
  final String ipAddress;
  final String softwareVersion;
  final bool active;
  final int uptimeSeconds;
  final String backhaulType; // Ethernet / Wi-Fi 5GHz / Wi-Fi 6GHz
  final int? backhaulRssi;
  final bool wifiEnabled;
  final int connectedDevicesCount;
  final List<String> connectedDeviceKeys;
  final List<RebootEntry> rebootHistory;

  const RepeaterInfo({
    required this.key,
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.softwareVersion,
    required this.active,
    required this.uptimeSeconds,
    required this.backhaulType,
    this.backhaulRssi,
    required this.wifiEnabled,
    required this.connectedDevicesCount,
    this.connectedDeviceKeys = const [],
    this.rebootHistory = const [],
  });

  RepeaterInfo copyWith({bool? wifiEnabled, int? uptimeSeconds}) =>
      RepeaterInfo(
        key: key,
        name: name,
        model: model,
        ipAddress: ipAddress,
        softwareVersion: softwareVersion,
        active: active,
        uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
        backhaulType: backhaulType,
        backhaulRssi: backhaulRssi,
        wifiEnabled: wifiEnabled ?? this.wifiEnabled,
        connectedDevicesCount: connectedDevicesCount,
        connectedDeviceKeys: connectedDeviceKeys,
        rebootHistory: rebootHistory,
      );
}

/// Orange TV Decoder.
class TvDecoderInfo {
  final String key;
  final String name;
  final String model;
  final String ipAddress;
  final bool active;
  final bool standby;
  final String mediaType; // LIVE, VOD, APP, STANDBY
  final String mediaState; // PLAY, PAUSE, IDLE
  final String channelName;
  final int channelNumber;
  final String currentProgram;

  const TvDecoderInfo({
    required this.key,
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.active,
    required this.standby,
    required this.mediaType,
    required this.mediaState,
    required this.channelName,
    required this.channelNumber,
    required this.currentProgram,
  });

  TvDecoderInfo copyWith({
    bool? standby,
    String? mediaType,
    String? mediaState,
    String? channelName,
    int? channelNumber,
    String? currentProgram,
  }) =>
      TvDecoderInfo(
        key: key,
        name: name,
        model: model,
        ipAddress: ipAddress,
        active: active,
        standby: standby ?? this.standby,
        mediaType: mediaType ?? this.mediaType,
        mediaState: mediaState ?? this.mediaState,
        channelName: channelName ?? this.channelName,
        channelNumber: channelNumber ?? this.channelNumber,
        currentProgram: currentProgram ?? this.currentProgram,
      );
}

/// Reboot history record.
class RebootEntry {
  final DateTime bootDate;
  final String bootReason;
  final DateTime? shutdownDate;
  final String shutdownReason;

  const RebootEntry({
    required this.bootDate,
    required this.bootReason,
    this.shutdownDate,
    required this.shutdownReason,
  });
}

/// DynDNS host entry.
class DynDnsHost {
  final String service;
  final String hostname;
  final String username;
  final String status;
  final DateTime? lastUpdate;

  const DynDnsHost({
    required this.service,
    required this.hostname,
    required this.username,
    required this.status,
    this.lastUpdate,
  });
}

/// Static IPv4 route.
class StaticRoute {
  final String id;
  final String destination;
  final String gateway;
  final String interfaceName;

  const StaticRoute({
    required this.id,
    required this.destination,
    required this.gateway,
    required this.interfaceName,
  });
}

/// Wi-Fi band configuration.
class WifiBandConfig {
  final String key;
  final String band; // 2.4 GHz, 5 GHz, 6 GHz, Guest
  final bool enabled;
  final String ssid;
  final bool broadcastSsid;
  final String securityMode;
  final String channel;
  final String bandwidth;
  final bool macFiltering;

  const WifiBandConfig({
    required this.key,
    required this.band,
    required this.enabled,
    required this.ssid,
    required this.broadcastSsid,
    required this.securityMode,
    required this.channel,
    required this.bandwidth,
    required this.macFiltering,
  });

  WifiBandConfig copyWith({
    bool? enabled,
    String? ssid,
    bool? broadcastSsid,
    String? securityMode,
    String? channel,
    String? bandwidth,
  }) =>
      WifiBandConfig(
        key: key,
        band: band,
        enabled: enabled ?? this.enabled,
        ssid: ssid ?? this.ssid,
        broadcastSsid: broadcastSsid ?? this.broadcastSsid,
        securityMode: securityMode ?? this.securityMode,
        channel: channel ?? this.channel,
        bandwidth: bandwidth ?? this.bandwidth,
        macFiltering: macFiltering,
      );
}

class SpeedTestResult {
  final DateTime timestamp;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final String server;

  const SpeedTestResult({
    required this.timestamp,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.server,
  });
}

const List<String> kDeviceTypeOptions = [
  'Unknown',
  'Desktop',
  'Desktop Linux',
  'Desktop iOS',
  'Desktop Windows',
  'Laptop',
  'Laptop iOS',
  'Laptop Linux',
  'Laptop Windows',
  'Mobile',
  'Mobile Android',
  'Mobile iOS',
  'Tablet',
  'Tablet iOS',
  'Tablet Android',
  'TV',
  'Apple TV',
  'Chromecast',
  'Set-top Box TV UHD',
  'Game Console',
  'NAS',
  'Printer',
  'IP Camera',
  'Smart Plug',
  'Color Bulb',
  'HiFi',
  'Switch8',
  'WiFiExtender',
  'SAH AP',
  'Phone',
];
