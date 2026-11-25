import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'livebox_repository.dart';
import 'livebox_session.dart';

/// Direct pure-Dart Livebox repository communicating with an Orange Livebox
/// over its sysbus HTTP JSON-RPC API (`POST /ws`) and Orange TV Decoders over
/// HTTP port 8080 (`remoteControl/cmd`).
class RealLiveboxRepository implements LiveboxRepository {
  final LiveboxSession session;
  final String label;

  // Previous byte counters for computing delta bitrates per interface & device
  final Map<String, ({int rx, int tx, DateTime ts})> _prevCounters = {};
  final Map<String, ({int rx, int tx, DateTime ts})> _prevDeviceEventCounters = {};
  final Map<String, ({int rx, int tx, DateTime ts})> _prevWifiStationCounters = {};
  final Map<String, DeviceTrafficStats> _deviceStats = {};
  static final RegExp _macRegex =
      RegExp(r'([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})');
  List<NetworkDevice> _cachedDevices = [];
  List<TvDecoderInfo> _cachedDecoders = [];
  int _eventCounter = 0;

  RealLiveboxRepository(this.session, {required this.label});

  @override
  bool get isDemo => false;

  @override
  String get connectionLabel => label;

  @override
  Future<void> disconnect() => session.close();

  static String _detectCommercialModel(String productClass) {
    switch (productClass) {
      case 'Livebox 3':
        return 'Livebox 3';
      case 'Livebox 4':
        return 'Livebox 4';
      case 'Livebox Fibre':
        return 'Livebox 5';
      case 'Livebox 6':
        return 'Livebox 6';
      case 'Livebox 7':
        return 'Livebox 7';
      case 'Livebox W7':
        return 'Livebox W7';
      case 'Livebox Nautilus':
      case 'Livebox S':
        return 'Livebox S';
      default:
        return productClass.isNotEmpty ? productClass : 'Livebox';
    }
  }

  Future<Map<String, dynamic>> _safeCallMap(
    String service, {
    String? method,
    dynamic args,
    Duration timeout = LiveboxSession.defaultTimeout,
  }) async {
    try {
      final res = await session.callNoCheck(
        service,
        method: method,
        args: args,
        timeout: timeout,
      );
      if (res is Map<String, dynamic>) return res;
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> _safeCallRawData(
    String service, {
    String? method,
    dynamic args,
    Duration timeout = LiveboxSession.defaultTimeout,
  }) async {
    try {
      final res = await session.callRaw(
        service,
        method: method,
        args: args,
        timeout: timeout,
      );
      if (res['data'] is Map<String, dynamic>) {
        return res['data'] as Map<String, dynamic>;
      }
      if (res['status'] is Map<String, dynamic>) {
        return res['status'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<LiveboxInfo> fetchLiveboxInfo() async {
    final dev = await _safeCallMap('DeviceInfo', method: 'get');
    final mem = await _safeCallMap('DeviceInfo.MemoryStatus', method: 'get');
    final wan = await _safeCallRawData('NMC', method: 'getWANStatus');
    final ipv6 = await _safeCallRawData('NMC.IPv6', method: 'get');
    final lan = await _safeCallRawData('NMC', method: 'getLANIP');
    final wifi = await _safeCallMap('NMC.Wifi', method: 'get');
    final guest = await _safeCallMap('NMC.Guest', method: 'get');
    final led = await _safeCallMap('LEDs.LED.Orange', method: 'get');

    // Optional ONT / SFP optical info
    double? rxDbm;
    double? txDbm;
    double? tempC;
    double? voltV;
    String? ontModel;
    String? ontSerial;

    try {
      final gpon = await _safeCallMap(
        'NeMo.Intf.veip0',
        method: 'getMIBs',
        args: {'mibs': 'gpon'},
      );
      final veip = (gpon['gpon'] is Map) ? (gpon['gpon']['veip0'] as Map?) : null;
      if (veip != null) {
        ontModel = veip['EquipmentID']?.toString();
        ontSerial = veip['SerialNumber']?.toString();
        if (veip['SignalRxPower'] is num) {
          rxDbm = (veip['SignalRxPower'] as num).toDouble() / 1000.0;
        }
        if (veip['SignalTxPower'] is num) {
          txDbm = (veip['SignalTxPower'] as num).toDouble() / 1000.0;
        }
        if (veip['Temperature'] is num) {
          tempC = (veip['Temperature'] as num).toDouble();
        }
        if (veip['Voltage'] is num) {
          voltV = (veip['Voltage'] as num).toDouble() / 1000.0;
        }
      }
    } catch (_) {}

    if (rxDbm == null) {
      final sfp = await _safeCallMap('SFP', method: 'get');
      if (sfp.isNotEmpty) {
        ontModel = sfp['ModelName']?.toString();
        ontSerial = sfp['SerialNumber']?.toString();
        if (sfp['OpticalSignalLevel'] is num) {
          rxDbm = (sfp['OpticalSignalLevel'] as num).toDouble() / 1000.0;
        }
        if (sfp['TransmitOpticalLevel'] is num) {
          txDbm = (sfp['TransmitOpticalLevel'] as num).toDouble() / 1000.0;
        }
        if (sfp['ChipsetTemperature'] is num) {
          tempC = (sfp['ChipsetTemperature'] as num).toDouble();
        }
      }
    }

    bool showWifiPwd = false;
    try {
      final s = await session.callNoCheck('Screen', method: 'getShowWifiPassword');
      showWifiPwd = s == true;
    } catch (_) {}

    final productClass = dev['ProductClass']?.toString() ?? '';
    final dnsRaw = wan['DNSServers']?.toString() ?? '';
    final dnsList = dnsRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return LiveboxInfo(
      modelName: _detectCommercialModel(productClass),
      productClass: productClass,
      manufacturer: dev['Manufacturer']?.toString() ?? 'Orange',
      serialNumber: dev['SerialNumber']?.toString() ?? '',
      hardwareVersion: dev['HardwareVersion']?.toString() ?? '',
      softwareVersion: dev['SoftwareVersion']?.toString() ?? '',
      macAddress: (dev['BaseMAC']?.toString() ?? '').toUpperCase(),
      uptimeSeconds: (dev['UpTime'] as num?)?.toInt() ?? 0,
      memoryTotalKb: (mem['Total'] as num?)?.toInt() ?? 0,
      memoryFreeKb: (mem['Free'] as num?)?.toInt() ?? 0,
      linkType: (wan['LinkType']?.toString() ?? 'gpon').toUpperCase(),
      linkState: wan['LinkState']?.toString() ?? 'up',
      wanStatus: wan['WanState']?.toString() ?? 'up',
      wanIpv4: wan['IPAddress']?.toString() ?? dev['ExternalIPAddress']?.toString() ?? '',
      wanIpv6: ipv6['IPv6Address']?.toString() ?? '',
      wanIpv6Prefix: ipv6['IPv6DelegatedPrefix']?.toString() ?? '',
      wanGateway: wan['RemoteGateway']?.toString() ?? '',
      dnsServers: dnsList,
      maxDownBitrateMbps: 2000,
      maxUpBitrateMbps: 800,
      ontModel: ontModel,
      ontSerial: ontSerial,
      opticalRxPowerDbm: rxDbm,
      opticalTxPowerDbm: txDbm,
      opticalTempC: tempC,
      opticalVoltageV: voltV,
      lanIp: lan['Address']?.toString() ?? '192.168.1.1',
      lanMask: lan['Netmask']?.toString() ?? '255.255.255.0',
      wifiEnabled: wifi['Enable'] == true || wifi['Status'] == true,
      guestWifiEnabled:
          guest['Status']?.toString().toLowerCase() == 'enabled' ||
          guest['Enable'] == true,
      wifiSchedulerEnabled: false,
      voipRegistered: true,
      voipNumber: '',
      iptvEnabled: true,
      usbDeviceCount: 0,
      orangeLedLevel: (led['Brightness'] as num?)?.toInt() ?? 255,
      showWifiPasswordOnScreen: showWifiPwd,
    );
  }

  static String _friendlyIntfName(String raw) {
    const map = {
      'WAN_Ethernet': 'WAN Ethernet',
      'WAN_GPON': 'Fiber GPON',
      'WAN_XGSPON': 'Fiber XGS-PON',
      'LAN-2.5G': 'Ethernet 2.5G',
      'LAN-10G': 'Ethernet 10G',
      'eth1': 'Ethernet 1',
      'eth2': 'Ethernet 2',
      'eth3': 'Ethernet 3',
      'eth4': 'Ethernet 4',
      '2.4GHz-Private_SSID': 'Wi-Fi 2.4 GHz',
      '5GHz-Private_SSID': 'Wi-Fi 5 GHz',
      '6GHz-Private_SSID': 'Wi-Fi 6 GHz',
      '2.4GHz-Guest_SSID': 'Guest Wi-Fi 2.4 GHz',
      '5GHz-Guest_SSID': 'Guest Wi-Fi 5 GHz',
    };
    return map[raw] ?? raw;
  }

  @override
  Future<List<NetworkInterfaceInfo>> fetchInterfaces() async {
    final raw = await _safeCallMap('HomeLan.Interface', method: 'get');
    final list = <NetworkInterfaceInfo>[];

    for (final entry in raw.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is! Map) continue;
      final alias = val['Alias']?.toString() ?? '';
      final friendly = val['FriendlyName']?.toString() ?? key;
      if (alias == 'WAN_Virtual') continue;

      String type = 'eth';
      String? band;
      if (friendly == 'WAN_GPON' || friendly == 'WAN_XGSPON' || friendly == 'WAN_Ethernet') {
        type = 'wan';
      } else if (alias == 'WiFi') {
        type = friendly.contains('Guest') ? 'gwi' : 'wif';
        if (friendly.startsWith('2.4')) band = '2.4 GHz';
        if (friendly.startsWith('5')) band = '5 GHz';
        if (friendly.startsWith('6')) band = '6 GHz';
      }

      int rx = 0;
      int tx = 0;
      try {
        final stats = await _safeCallMap('NeMo.Intf.$key', method: 'getNetDevStats');
        rx = (stats['RxBytes'] as num?)?.toInt() ?? 0;
        tx = (stats['TxBytes'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      list.add(NetworkInterfaceInfo(
        key: key,
        name: _friendlyIntfName(friendly),
        type: type,
        enabled: true,
        up: true,
        speedMbps: friendly.contains('10G')
            ? 10000
            : friendly.contains('2.5G')
                ? 2500
                : 1000,
        band: band,
        rxBytes: rx,
        txBytes: tx,
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
      ));
    }
    return list;
  }

  @override
  Future<List<NetworkDevice>> fetchDevices() async {
    final raw = await session.callNoCheck(
      'Devices',
      method: 'get',
      args: {'expression': 'physical and !self and !voice'},
      timeout: const Duration(seconds: 12),
    );
    if (raw is! List) return [];

    final devices = <NetworkDevice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final mac = (item['Key']?.toString() ?? item['PhysAddress']?.toString() ?? '')
          .toUpperCase();
      if (mac.isEmpty) continue;

      final tags = (item['Tags']?.toString() ?? '').split(' ').where((e) => e.isNotEmpty).toList();
      final isWifi = tags.contains('wifi') || item['SignalStrength'] != null;
      final band = item['OperatingFrequencyBand']?.toString() ?? '';
      String linkType = 'eth';
      if (isWifi) {
        if (band.contains('6')) {
          linkType = 'wifi6';
        } else if (band.contains('5')) {
          linkType = 'wifi5';
        } else {
          linkType = 'wifi24';
        }
      }

      String ipv6 = '';
      if (item['IPv6Address'] is List) {
        for (final a in (item['IPv6Address'] as List)) {
          if (a is Map && a['Scope'] == 'global' && a['Address'] != null) {
            ipv6 = a['Address'].toString();
            break;
          }
        }
      }

      bool reserved = item['IPAddressSource']?.toString().toLowerCase() == 'static';
      if (item['IPv4Address'] is List) {
        for (final a in (item['IPv4Address'] as List)) {
          if (a is Map && a['Reserved'] == true) {
            reserved = true;
            break;
          }
        }
      }

      String dnsName = '';
      if (item['Names'] is List) {
        for (final n in (item['Names'] as List)) {
          if (n is Map && n['Source'] == 'dns' && n['Name'] != null) {
            dnsName = n['Name'].toString();
            break;
          }
        }
      }

      final name = item['Name']?.toString() ?? mac;
      final downKbps = (item['LastDataDownlinkRate'] as num?)?.toInt();
      final cachedStat = _deviceStats[mac];

      devices.add(NetworkDevice(
        key: mac,
        name: name.isNotEmpty ? name : mac,
        liveboxName: name,
        dnsName: dnsName,
        deviceType: item['DeviceType']?.toString() ?? 'Unknown',
        vendor: item['MACVendor']?.toString() ??
            (item['BDD'] is Map ? (item['BDD']['Manufacturer']?.toString() ?? '') : ''),
        ipAddress: item['IPAddress']?.toString() ?? '',
        ipv6Address: ipv6,
        active: item['Active'] == true,
        blocked: false,
        staticIp: reserved,
        interfaceKey: item['InterfaceName']?.toString() ?? '',
        interfaceName: item['InterfaceName']?.toString() ?? (isWifi ? 'Wi-Fi' : 'Ethernet'),
        linkType: linkType,
        rssi: (item['SignalStrength'] as num?)?.toInt(),
        linkSpeedMbps: downKbps != null ? (downKbps ~/ 1000) : null,
        rxBytes: cachedStat?.rxBytes ?? 0,
        txBytes: cachedStat?.txBytes ?? 0,
        rxBytesPerSec: cachedStat?.rxBytesPerSec ?? 0,
        txBytesPerSec: cachedStat?.txBytesPerSec ?? 0,
        firstSeen: DateTime.tryParse(item['FirstSeen']?.toString() ?? ''),
        lastChanged: DateTime.tryParse(item['LastChanged']?.toString() ?? ''),
        tags: tags,
      ));
    }

    _cachedDevices = devices;
    return devices;
  }

  @override
  Future<void> renameDevice(String mac, String newName) async {
    await session.call('Devices.Device.$mac', method: 'setName', args: {'name': newName});
  }

  @override
  Future<void> setDeviceType(String mac, String newType) async {
    await session.call('Devices.Device.$mac', method: 'setType', args: {'type': newType});
  }

  @override
  Future<void> setDeviceBlocked(String mac, bool blocked) async {
    await session.callNoCheck(
      'Scheduler',
      method: 'addSchedule',
      args: {
        'type': 'ToD',
        'info': {
          'ID': mac,
          'base': 'Weekly',
          'def': 'Enable',
          'schedule': <dynamic>[],
          'enable': true,
          'override': blocked ? 'Disable' : 'Enable',
        },
      },
    );
  }

  @override
  Future<void> wakeOnLan(String mac) async {
    await session.callNoCheck('WOL', method: 'sendWakeOnLan', args: {
      'hostID': mac,
      'broadcast': true,
    });
  }

  @override
  Future<void> deleteDevice(String mac) async {
    await session.callNoCheck('Devices', method: 'destroyDevice', args: {'key': mac});
  }

  static int _deltaCounter(int current, int previous) {
    if (current >= previous) return current - previous;
    // Handle 32-bit unsigned counter wrap (4 GiB) on Livebox NetDev/station stats
    const uint32Max = 0x100000000;
    if (previous < uint32Max && current < uint32Max) {
      return (uint32Max - previous) + current;
    }
    return 0;
  }

  @override
  Future<Map<String, TrafficSample>> sampleTraffic(List<String> interfaceKeys) async {
    final now = DateTime.now();
    final out = <String, TrafficSample>{};

    for (final key in interfaceKeys) {
      try {
        final stats = await _safeCallMap('NeMo.Intf.$key', method: 'getNetDevStats');
        if (stats.isEmpty ||
            (stats['RxBytes'] == null && stats['TxBytes'] == null)) {
          continue;
        }
        final rx = (stats['RxBytes'] as num?)?.toInt() ?? 0;
        final tx = (stats['TxBytes'] as num?)?.toInt() ?? 0;
        final prev = _prevCounters[key];
        _prevCounters[key] = (rx: rx, tx: tx, ts: now);

        if (prev != null) {
          final dtSec = now.difference(prev.ts).inMilliseconds / 1000.0;
          if (dtSec > 0.1) {
            final dRx = _deltaCounter(rx, prev.rx);
            final dTx = _deltaCounter(tx, prev.tx);
            out[key] = TrafficSample(
              timestamp: now,
              downMbps: (dRx * 8.0) / (dtSec * 1e6),
              upMbps: (dTx * 8.0) / (dtSec * 1e6),
            );
          }
        } else {
          out[key] = TrafficSample(timestamp: now, downMbps: 0, upMbps: 0);
        }
      } catch (_) {}
    }
    return out;
  }

  @override
  Future<Map<String, DeviceTrafficStats>> sampleDeviceTraffic(
      List<NetworkInterfaceInfo> interfaces) async {
    final now = DateTime.now();

    // Poll real-time Wi-Fi station stats on each Wi-Fi VAP interface
    // (mirrors LiveboxWifiStatsThread in LmDeviceListTab.py)
    for (final intf in interfaces) {
      if (intf.type != 'wif' && intf.type != 'gwi') continue;
      try {
        final raw = await session.callNoCheck(
          'NeMo.Intf.${intf.key}',
          method: 'getStationStats',
        );
        if (raw is! List) continue;
        for (final stat in raw) {
          if (stat is! Map) continue;
          final mac = (stat['MACAddress']?.toString() ?? '').toUpperCase();
          if (mac.isEmpty) continue;

          // Router TxBytes = device download (Rx), Router RxBytes = device upload (Tx)
          final devRx = (stat['TxBytes'] as num?)?.toInt() ?? 0;
          final devTx = (stat['RxBytes'] as num?)?.toInt() ?? 0;
          final stationKey = '${mac}_${intf.key}';
          final prev = _prevWifiStationCounters[stationKey];
          _prevWifiStationCounters[stationKey] = (rx: devRx, tx: devTx, ts: now);

          double rxRate = _deviceStats[mac]?.rxBytesPerSec ?? 0;
          double txRate = _deviceStats[mac]?.txBytesPerSec ?? 0;
          if (prev != null) {
            final dtSec = now.difference(prev.ts).inMilliseconds / 1000.0;
            if (dtSec > 0.1) {
              rxRate = _deltaCounter(devRx, prev.rx) / dtSec;
              txRate = _deltaCounter(devTx, prev.tx) / dtSec;
            }
          }

          final existing = _deviceStats[mac];
          _deviceStats[mac] = DeviceTrafficStats(
            rxBytes: devRx > (existing?.rxBytes ?? 0) ? devRx : (existing?.rxBytes ?? devRx),
            txBytes: devTx > (existing?.txBytes ?? 0) ? devTx : (existing?.txBytes ?? devTx),
            rxBytesPerSec: rxRate,
            txBytesPerSec: txRate,
          );
        }
      } catch (_) {}
    }

    return Map<String, DeviceTrafficStats>.of(_deviceStats);
  }

  void _processDeviceStatisticsEvent(String mac, Map<dynamic, dynamic> attr) {
    // Attributes can be keyed by MAC (matching case or lowercase) or direct RxBytes/TxBytes
    Map<dynamic, dynamic>? statMap;
    if (attr.containsKey('RxBytes') || attr.containsKey('TxBytes')) {
      statMap = attr;
    } else {
      for (final entry in attr.entries) {
        if (entry.key.toString().toUpperCase() == mac && entry.value is Map) {
          statMap = entry.value as Map;
          break;
        }
      }
    }
    if (statMap == null) return;

    final rx = (statMap['RxBytes'] as num?)?.toInt() ?? 0;
    final tx = (statMap['TxBytes'] as num?)?.toInt() ?? 0;
    final ts = DateTime.tryParse(statMap['Timestamp']?.toString() ?? '') ?? DateTime.now();

    final prev = _prevDeviceEventCounters[mac];
    _prevDeviceEventCounters[mac] = (rx: rx, tx: tx, ts: ts);

    double rxRate = _deviceStats[mac]?.rxBytesPerSec ?? 0;
    double txRate = _deviceStats[mac]?.txBytesPerSec ?? 0;
    if (prev != null) {
      final dtSec = ts.difference(prev.ts).inMilliseconds / 1000.0;
      if (dtSec > 0.1) {
        rxRate = _deltaCounter(rx, prev.rx) / dtSec;
        txRate = _deltaCounter(tx, prev.tx) / dtSec;
      }
    }

    _deviceStats[mac] = DeviceTrafficStats(
      rxBytes: rx,
      txBytes: tx,
      rxBytesPerSec: rxRate,
      txBytesPerSec: txRate,
    );
  }

  @override
  Future<List<LiveboxEvent>> pollEvents() async {
    final res = await session.eventRequest(
      ['Devices.Device', 'HomeLan', 'AutoDiag', 'Firewall'],
      timeout: const Duration(seconds: 2),
    );
    if (res == null || res['events'] is! List) return [];

    final out = <LiveboxEvent>[];
    for (final ev in (res['events'] as List)) {
      if (ev is! Map<String, dynamic>) continue;
      final data = ev['data'];
      if (data is! Map<String, dynamic>) continue;
      final handler = data['handler']?.toString() ?? 'Livebox';
      final obj = data['object'] is Map<String, dynamic>
          ? data['object'] as Map<String, dynamic>
          : <String, dynamic>{};
      final reason = obj['reason']?.toString() ?? 'event';

      String devKey = 'LIVEBOX';
      final macMatch = _macRegex.firstMatch(handler);
      if (macMatch != null) {
        devKey = macMatch.group(1)!.toUpperCase();
      } else if (handler.startsWith('Devices.Device.')) {
        devKey = handler.replaceFirst('Devices.Device.', '').split('.').first.toUpperCase();
      }

      if (reason == 'Statistics' && devKey != 'LIVEBOX' && obj['attributes'] is Map) {
        _processDeviceStatisticsEvent(devKey, obj['attributes'] as Map);
      }

      final match = _cachedDevices.where((d) => d.key == devKey).firstOrNull;
      out.add(LiveboxEvent(
        id: 'ev_${++_eventCounter}',
        timestamp: DateTime.now(),
        deviceKey: devKey,
        deviceName: match?.name ?? (devKey == 'LIVEBOX' ? 'Livebox' : devKey),
        reason: reason,
        summary: '$handler · $reason',
        rawPayload: ev,
      ));
    }
    return out;
  }

  @override
  Future<DhcpConfig> fetchDhcpConfig() async {
    final lan = await _safeCallRawData('NMC', method: 'getLANIP');
    final ipv6 = await _safeCallRawData('NMC.IPv6', method: 'get');
    return DhcpConfig(
      enabled: lan['DHCPEnable'] == true,
      lanIp: lan['Address']?.toString() ?? '192.168.1.1',
      subnetMask: lan['Netmask']?.toString() ?? '255.255.255.0',
      minAddress: lan['DHCPMinAddress']?.toString() ?? '192.168.1.10',
      maxAddress: lan['DHCPMaxAddress']?.toString() ?? '192.168.1.150',
      leaseTimeSeconds: 86400,
      dhcpv6Enabled: ipv6['Enable'] == true,
      ipv6Prefix: ipv6['IPv6DelegatedPrefix']?.toString() ?? '',
    );
  }

  @override
  Future<void> saveDhcpConfig(DhcpConfig config) async {
    await session.callRaw(
      'NetMaster.LAN.default.Bridge.lan',
      method: 'setIPv4',
      args: {
        'Address': config.lanIp,
        'Netmask': config.subnetMask,
        'DHCPEnable': config.enabled,
        'DHCPMinAddress': config.minAddress,
        'DHCPMaxAddress': config.maxAddress,
        'PrefixLength': 24,
      },
    );
  }

  @override
  Future<List<DhcpBinding>> fetchDhcpBindings() async {
    final res = await session.callNoCheck(
      'DHCPv4.Server.Pool.default',
      method: 'getStaticLeases',
      args: 'default',
    );
    final list = <DhcpBinding>[];
    if (res is List) {
      for (final item in res) {
        if (item is! Map) continue;
        final mac = (item['MACAddress']?.toString() ?? '').toUpperCase();
        final match = _cachedDevices.where((d) => d.key == mac).firstOrNull;
        list.add(DhcpBinding(
          macAddress: mac,
          ipAddress: item['IPAddress']?.toString() ?? '',
          deviceName: match?.name ?? mac,
          isStatic: true,
          active: match?.active ?? false,
          domain: 'default',
        ));
      }
    }
    return list;
  }

  @override
  Future<void> addDhcpBinding(String mac, String ip) async {
    await session.callNoCheck(
      'DHCPv4.Server.Pool.default',
      method: 'addStaticLease',
      args: {'MACAddress': mac.toUpperCase(), 'IPAddress': ip},
    );
  }

  @override
  Future<void> deleteDhcpBinding(String mac) async {
    await session.callNoCheck(
      'DHCPv4.Server.Pool.default',
      method: 'deleteStaticLease',
      args: {'MACAddress': mac.toUpperCase()},
    );
  }

  @override
  Future<List<NatPatRule>> fetchNatPatRules() async {
    final map = await _safeCallMap('Firewall', method: 'getPortForwarding');
    final list = <NatPatRule>[];
    for (final entry in map.entries) {
      if (entry.value is! Map) continue;
      final r = entry.value as Map;
      final origin = r['Origin']?.toString() ?? 'webui';
      list.add(NatPatRule(
        id: entry.key,
        name: r['Description']?.toString() ?? entry.key,
        type: origin == 'upnp' ? 'UPnP' : 'IPv4',
        enabled: r['Enable'] == true,
        protocol: _protoName(r['Protocol']?.toString() ?? '6'),
        externalPort: r['ExternalPort']?.toString() ?? '',
        internalPort: r['InternalPort']?.toString() ?? '',
        destinationIp: r['DestinationIPAddress']?.toString() ?? '',
        externalIps: r['SourcePrefix']?.toString().isNotEmpty == true
            ? r['SourcePrefix'].toString()
            : 'All',
        description: r['Description']?.toString() ?? '',
      ));
    }
    return list;
  }

  static String _protoName(String code) {
    if (code == '6') return 'TCP';
    if (code == '17') return 'UDP';
    if (code == '6,17') return 'TCP/UDP';
    return code;
  }

  static String _protoCode(String name) {
    switch (name.toUpperCase()) {
      case 'TCP':
        return '6';
      case 'UDP':
        return '17';
      case 'TCP/UDP':
        return '6,17';
      default:
        return name;
    }
  }

  @override
  Future<void> saveNatPatRule(NatPatRule rule) async {
    await session.callRaw('Firewall', method: 'setPortForwarding', args: {
      'id': rule.id,
      'internalPort': rule.internalPort,
      'externalPort': rule.externalPort,
      'destinationIPAddress': rule.destinationIp,
      'enable': rule.enabled,
      'persistent': true,
      'protocol': _protoCode(rule.protocol),
      'description': rule.name,
      'sourceInterface': 'data',
      'origin': 'webui',
      'destinationMACAddress': '',
      if (rule.externalIps.isNotEmpty && rule.externalIps != 'All')
        'sourcePrefix': rule.externalIps,
    });
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<void> deleteNatPatRule(NatPatRule rule) async {
    final origin = rule.type == 'UPnP' ? 'upnp' : 'webui';
    final prefixedId = rule.id.startsWith('${origin}_') ? rule.id : '${origin}_${rule.id}';
    await session.callNoCheck('Firewall', method: 'deletePortForwarding', args: {
      'id': prefixedId,
      'destinationIPAddress': rule.destinationIp,
      'origin': origin,
    });
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<List<PtfRule>> fetchPtfRules() async {
    final map = await _safeCallMap('Firewall', method: 'getProtocolForwarding');
    return map.entries.where((e) => e.value is Map).map((e) {
      final r = e.value as Map;
      return PtfRule(
        id: e.key,
        name: r['Description']?.toString() ?? e.key,
        enabled: r['Enable'] == true,
        protocol: r['Protocol']?.toString() ?? 'GRE',
        destinationIp: r['DestinationIPAddress']?.toString() ?? '',
        externalIps: r['SourcePrefix']?.toString() ?? 'All',
      );
    }).toList();
  }

  @override
  Future<void> savePtfRule(PtfRule rule) async {
    await session.callRaw('Firewall', method: 'setProtocolForwarding', args: {
      'id': rule.id,
      'enable': rule.enabled,
      'destinationIPAddress': rule.destinationIp,
      'protocol': rule.protocol,
      'persistent': true,
      'description': rule.name,
    });
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<void> deletePtfRule(String id) async {
    await session.callNoCheck('Firewall', method: 'deleteProtocolForwarding', args: {'id': id});
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<DmzConfig> fetchDmz() async {
    final map = await _safeCallMap('Firewall', method: 'getDMZ');
    if (map.isNotEmpty) {
      final first = map.values.first;
      if (first is Map) {
        return DmzConfig(
          enabled: first['Enable'] == true,
          destinationIp: first['DestinationIPAddress']?.toString() ?? '',
          externalIps: first['SourcePrefix']?.toString() ?? '',
        );
      }
    }
    return const DmzConfig(enabled: false, destinationIp: '');
  }

  @override
  Future<void> saveDmz(DmzConfig config) async {
    if (config.enabled && config.destinationIp.isNotEmpty) {
      await session.callNoCheck('Firewall', method: 'setDMZ', args: {
        'id': 'webui',
        'sourceInterface': 'data',
        'destinationIPAddress': config.destinationIp,
        'enable': true,
        if (config.externalIps.isNotEmpty) 'sourcePrefix': config.externalIps,
      });
    } else {
      await session.callNoCheck('Firewall', method: 'deleteDMZ', args: {'id': 'webui'});
    }
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<FirewallState> fetchFirewall() async {
    String v4 = 'Medium';
    String v6 = 'Medium';
    try {
      v4 = (await session.callNoCheck('Firewall', method: 'getFirewallLevel'))?.toString() ?? 'Medium';
    } catch (_) {}
    try {
      v6 = (await session.callNoCheck('Firewall', method: 'getFirewallIPv6Level'))?.toString() ?? 'Medium';
    } catch (_) {}
    final ping = await _safeCallMap('Firewall', method: 'getRespondToPing', args: {'sourceInterface': 'data'});
    final customMap = await _safeCallMap('Firewall', method: 'getCustomRule', args: {'chain': 'Custom'});

    final rules = customMap.entries.where((e) => e.value is Map).map((e) {
      final r = e.value as Map;
      return FirewallRule(
        id: e.key,
        enabled: r['Enable'] == true,
        isIpv6: (r['IPVersion'] as num?)?.toInt() == 6,
        action: r['Action']?.toString() ?? 'Accept',
        protocol: _protoName(r['Protocol']?.toString() ?? '6'),
        sourcePrefix: r['SourcePrefix']?.toString() ?? '',
        sourcePort: r['SourcePort']?.toString() ?? '',
        destinationPrefix: r['DestinationPrefix']?.toString() ?? '',
        destinationPort: r['DestinationPort']?.toString() ?? '',
        description: r['Description']?.toString() ?? e.key,
      );
    }).toList();

    return FirewallState(
      ipv4Level: v4,
      ipv6Level: v6,
      respondToPingIpv4: ping['enableIPv4'] == true,
      respondToPingIpv6: ping['enableIPv6'] == true,
      rules: rules,
    );
  }

  @override
  Future<void> setFirewallLevels(String ipv4Level, String ipv6Level) async {
    await session.callNoCheck('Firewall', method: 'setFirewallLevel', args: {'level': ipv4Level});
    await session.callNoCheck('Firewall', method: 'setFirewallIPv6Level', args: {'level': ipv6Level});
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<void> setRespondToPing(bool ipv4, bool ipv6) async {
    await session.callNoCheck('Firewall', method: 'setRespondToPing', args: {
      'sourceInterface': 'data',
      'service_enable': {'enableIPv4': ipv4, 'enableIPv6': ipv6},
    });
  }

  @override
  Future<void> saveFirewallRule(FirewallRule rule) async {
    await session.callNoCheck('Firewall', method: 'setCustomRule', args: {
      'id': rule.id,
      'enable': rule.enabled,
      'description': rule.description,
      'protocol': _protoCode(rule.protocol),
      'action': rule.action,
      'destinationPort': rule.destinationPort,
      'destinationPrefix': rule.destinationPrefix,
      'sourcePort': rule.sourcePort,
      'sourcePrefix': rule.sourcePrefix,
      'persistent': true,
      'ipversion': rule.isIpv6 ? 6 : 4,
      'chain': 'Custom',
    });
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<void> deleteFirewallRule(String id) async {
    await session.callNoCheck('Firewall', method: 'deleteCustomRule', args: {
      'id': id,
      'chain': 'Custom',
    });
    await session.callNoCheck('Firewall', method: 'commit');
  }

  @override
  Future<List<PhoneCallEntry>> fetchCallLog() async {
    final res = await session.callNoCheck(
      'VoiceService.VoiceApplication',
      method: 'getCallList',
      args: [
        {'line': '1'},
      ],
      timeout: const Duration(seconds: 8),
    );
    if (res is! List) return [];
    return res.whereType<Map>().map((c) {
      final typeStr = c['callType']?.toString().toLowerCase() ?? '';
      final originStr = c['callOrigin']?.toString().toLowerCase() ?? '';
      CallType type = CallType.incoming;
      if (typeStr.contains('missed')) {
        type = CallType.missed;
      } else if (typeStr.contains('fail')) {
        type = CallType.failed;
      } else if (originStr.contains('local') || typeStr.contains('out')) {
        type = CallType.outgoing;
      }
      return PhoneCallEntry(
        id: c['callId']?.toString() ?? '',
        type: type,
        timestamp: DateTime.tryParse(c['startTime']?.toString() ?? '') ?? DateTime.now(),
        number: c['remoteNumber']?.toString() ?? '',
        contactName: c['remoteName']?.toString() ?? '',
        durationSeconds: (c['duration'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> deleteCall(String id) async {
    await session.callNoCheck(
      'VoiceService.VoiceApplication',
      method: 'clearCallList',
      args: {'callId': id},
    );
  }

  @override
  Future<void> ringPhones() async {
    await session.callNoCheck('VoiceService.VoiceApplication', method: 'ring');
  }

  @override
  Future<List<PhoneContact>> fetchContacts() async {
    final res = await session.callNoCheck(
      'Phonebook',
      method: 'getAllContacts',
      timeout: const Duration(seconds: 15),
    );
    if (res is! List) return [];
    return res.whereType<Map>().map((c) {
      final rawName = c['name']?.toString() ?? '';
      String first = '';
      String last = c['formattedName']?.toString() ?? '';
      if (rawName.startsWith('N:')) {
        final parts = rawName.substring(2).split(';');
        last = parts.isNotEmpty ? parts[0] : '';
        first = parts.length > 1 ? parts[1] : '';
      }
      String cell = '', home = '', work = '';
      if (c['telephoneNumbers'] is List) {
        for (final t in (c['telephoneNumbers'] as List)) {
          if (t is! Map) continue;
          final numStr = t['name']?.toString() ?? '';
          switch (t['type']?.toString().toUpperCase()) {
            case 'CELL':
              cell = numStr;
            case 'HOME':
              home = numStr;
            case 'WORK':
              work = numStr;
          }
        }
      }
      return PhoneContact(
        id: c['uniqueID']?.toString() ?? '',
        firstName: first,
        lastName: last,
        cellNumber: cell,
        homeNumber: home,
        workNumber: work,
        ringtone: c['ringtone']?.toString() ?? '1',
      );
    }).toList();
  }

  @override
  Future<void> saveContact(PhoneContact contact) async {
    final payload = {
      'name': 'N:${contact.lastName};${contact.firstName};',
      'formattedName': contact.fullName,
      'ringtone': contact.ringtone,
      'telephoneNumbers': [
        if (contact.cellNumber.isNotEmpty)
          {'name': contact.cellNumber, 'type': 'CELL', 'preferred': true},
        if (contact.homeNumber.isNotEmpty)
          {'name': contact.homeNumber, 'type': 'HOME', 'preferred': false},
        if (contact.workNumber.isNotEmpty)
          {'name': contact.workNumber, 'type': 'WORK', 'preferred': false},
      ],
    };
    if (contact.id.isEmpty) {
      await session.callNoCheck('Phonebook', method: 'addContactAndGenUUID', args: {'contact': payload});
    } else {
      await session.callNoCheck('Phonebook', method: 'modifyContactByUniqueID', args: {
        'uniqueID': contact.id,
        'contact': payload,
      });
    }
  }

  @override
  Future<void> deleteContact(String id) async {
    await session.callNoCheck('Phonebook', method: 'removeContactByUniqueID', args: {'uniqueID': id});
  }

  @override
  Future<List<RepeaterInfo>> fetchRepeaters() async {
    final devices = _cachedDevices.isEmpty ? await fetchDevices() : _cachedDevices;
    return devices
        .where((d) =>
            d.deviceType.toLowerCase().contains('sah ap') ||
            d.deviceType.toLowerCase().contains('repeteur') ||
            d.deviceType.toLowerCase().contains('repeater') ||
            d.tags.contains('ssw_ap'))
        .map((d) => RepeaterInfo(
              key: d.key,
              name: d.name,
              model: d.deviceType,
              ipAddress: d.ipAddress,
              softwareVersion: 'Detected on LAN',
              active: d.active,
              uptimeSeconds: 0,
              backhaulType: d.isWifi ? 'Wi-Fi' : 'Ethernet',
              backhaulRssi: d.rssi,
              wifiEnabled: true,
              connectedDevicesCount: 0,
            ))
        .toList();
  }

  @override
  Future<void> setRepeaterWifi(String mac, bool enabled) async {
    // Repeaters have their own session in full multi-session mode
  }

  @override
  Future<void> rebootRepeater(String mac) async {}

  @override
  Future<List<TvDecoderInfo>> fetchTvDecoders() async {
    final devices = _cachedDevices.isEmpty ? await fetchDevices() : _cachedDevices;
    final decoders = devices
        .where((d) =>
            d.deviceType.toLowerCase().contains('set-top') ||
            d.tags.contains('stb'))
        .toList();

    final result = <TvDecoderInfo>[];
    for (final d in decoders) {
      bool standby = false;
      String mediaType = 'LIVE';
      String mediaState = 'PLAY';
      String channel = 'Live TV';
      if (d.active && d.ipAddress.isNotEmpty) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
          final req = await client.getUrl(
            Uri.parse('http://${d.ipAddress}:8080/remoteControl/cmd?operation=10'),
          );
          final resp = await req.close().timeout(const Duration(seconds: 2));
          final txt = await resp.transform(utf8.decoder).join();
          final json = jsonDecode(txt);
          final data = json['result']?['data'];
          if (data is Map) {
            standby = data['activeStandbyState']?.toString() == '1';
            mediaType = data['playedMediaType']?.toString() ?? (data['osdContext']?.toString() ?? 'LIVE');
            mediaState = data['playedMediaState']?.toString() ?? (standby ? 'STANDBY' : 'PLAY');
            channel = data['osdContext']?.toString() ?? 'Live TV';
          }
          client.close();
        } catch (_) {}
      }
      result.add(TvDecoderInfo(
        key: d.key,
        name: d.name,
        model: d.deviceType,
        ipAddress: d.ipAddress,
        active: d.active,
        standby: standby,
        mediaType: mediaType,
        mediaState: mediaState,
        channelName: channel,
        channelNumber: 1,
        currentProgram: '',
      ));
    }
    _cachedDecoders = result;
    return result;
  }

  @override
  Future<TvDecoderInfo> sendTvRemoteKey(String decoderKey, int keyCode) async {
    final dec = _cachedDecoders.firstWhere((d) => d.key == decoderKey);
    if (dec.ipAddress.isNotEmpty) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final req = await client.getUrl(Uri.parse(
          'http://${dec.ipAddress}:8080/remoteControl/cmd?operation=01&key=$keyCode&mode=0',
        ));
        await (await req.close()).drain<void>();
      } finally {
        client.close();
      }
    }
    final refreshed = await fetchTvDecoders();
    return refreshed.firstWhere((d) => d.key == decoderKey, orElse: () => dec);
  }

  @override
  Future<TvDecoderInfo> zapTvChannel(
      String decoderKey, int channelNumber, String channelName) async {
    final dec = _cachedDecoders.firstWhere((d) => d.key == decoderKey);
    // Send digit keys sequentially (512 + digit)
    for (final ch in channelNumber.toString().split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        await sendTvRemoteKey(decoderKey, 512 + digit);
      }
    }
    return dec.copyWith(channelNumber: channelNumber, channelName: channelName);
  }

  @override
  Future<List<WifiBandConfig>> fetchWifiBands() async {
    final mibs = await _safeCallMap(
      'NeMo.Intf.lan',
      method: 'getMIBs',
      args: {'mibs': 'base wlanradio wlanvap'},
      timeout: const Duration(seconds: 20),
    );
    final vaps = mibs['wlanvap'] is Map ? mibs['wlanvap'] as Map : {};
    final radios = mibs['wlanradio'] is Map ? mibs['wlanradio'] as Map : {};
    final base = mibs['base'] is Map ? mibs['base'] as Map : {};

    final out = <WifiBandConfig>[];
    for (final entry in vaps.entries) {
      if (entry.value is! Map) continue;
      final v = entry.value as Map;
      final key = entry.key.toString();
      final b = base[key] is Map ? base[key] as Map : {};
      final radioKey = v['Radio']?.toString() ?? '';
      final r = radios[radioKey] is Map ? radios[radioKey] as Map : {};
      final sec = v['Security'] is Map ? v['Security'] as Map : {};
      final macF = v['MACFiltering'] is Map ? v['MACFiltering'] as Map : {};

      out.add(WifiBandConfig(
        key: key,
        band: key.contains('6g')
            ? '6 GHz'
            : key.contains('5g')
                ? '5 GHz'
                : '2.4 GHz',
        enabled: b['Enable'] == true || b['Status'] == true,
        ssid: v['SSID']?.toString() ?? '',
        broadcastSsid: v['SSIDAdvertisementEnabled'] != false,
        securityMode: sec['ModeEnabled']?.toString() ?? 'WPA2-Personal',
        channel: r['AutoChannelEnable'] == true
            ? 'Auto (${r['Channel'] ?? ''})'
            : (r['Channel']?.toString() ?? 'Auto'),
        bandwidth: r['OperatingChannelBandwidth']?.toString() ?? 'Auto',
        macFiltering: macF['Mode']?.toString().toLowerCase() == 'whitelist',
      ));
    }
    return out;
  }

  @override
  Future<void> setGlobalWifi(bool enabled) async {
    await session.callNoCheck('PowerManagement', method: 'setProfiles', args: {
      'profiles': [
        {'profile': 'WiFi', 'enable': enabled},
      ],
    });
    await session.callNoCheck('NMC.Wifi', method: 'set', args: {
      'Enable': enabled,
      'Status': enabled,
    });
  }

  @override
  Future<void> setGuestWifi(bool enabled, {int timerHours = 0}) async {
    await session.callNoCheck('NMC.Guest', method: 'set', args: {'Enable': enabled});
    if (enabled && timerHours > 0) {
      await session.callNoCheck('NMC.WlanTimer', method: 'setActivationTimer', args: {
        'Timeout': timerHours,
        'InterfaceName': 'guest',
      });
    } else if (!enabled) {
      await session.callNoCheck('NMC.WlanTimer', method: 'disableActivationTimer', args: {
        'InterfaceName': 'guest',
      });
    }
  }

  @override
  Future<void> setWifiScheduler(bool enabled) async {
    await session.callNoCheck('Scheduler', method: 'enableSchedule', args: {
      'type': 'WLAN',
      'ID': 'wl0',
      'enable': enabled,
    });
  }

  @override
  Future<void> saveWifiBand(WifiBandConfig band) async {
    await session.callNoCheck(
      'NeMo.Intf.lan',
      method: 'setWLANConfig',
      args: {
        'mibs': {
          'wlanvap': {
            band.key: {
              'SSID': band.ssid,
              'SSIDAdvertisementEnabled': band.broadcastSsid,
            },
          },
        },
      },
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<void> setLedBrightness(int level) async {
    await session.callNoCheck('LEDs.LED.Orange', method: 'set', args: {'Brightness': level});
  }

  @override
  Future<void> setShowWifiPasswordOnScreen(bool show) async {
    await session.callNoCheck('Screen', method: 'setShowWifiPassword', args: {'Enable': show});
  }

  @override
  Future<void> rebootLivebox() async {
    await session.callNoCheck('NMC', method: 'reboot', args: {'reason': 'GUI_Reboot'});
  }

  @override
  Future<List<RebootEntry>> fetchRebootHistory() async {
    final map = await _safeCallMap('NMC.Reboot.Reboot', method: 'get');
    return map.values.whereType<Map>().map((e) {
      return RebootEntry(
        bootDate: DateTime.tryParse(e['BootDate']?.toString() ?? '') ?? DateTime.now(),
        bootReason: e['BootReason']?.toString() ?? 'Unknown',
        shutdownDate: DateTime.tryParse(e['ShutdownDate']?.toString() ?? ''),
        shutdownReason: e['ShutdownReason']?.toString() ?? '',
      );
    }).toList();
  }

  @override
  Future<List<DynDnsHost>> fetchDynDnsHosts() async {
    final res = await session.callNoCheck('DynDNS', method: 'getHosts');
    if (res is! List) return [];
    return res.whereType<Map>().map((h) => DynDnsHost(
          service: h['service']?.toString() ?? '',
          hostname: h['hostname']?.toString() ?? '',
          username: h['username']?.toString() ?? '',
          status: h['status']?.toString() ?? 'updated',
          lastUpdate: DateTime.tryParse(h['last_update']?.toString() ?? ''),
        )).toList();
  }

  @override
  Future<void> addDynDnsHost(
      String service, String hostname, String username, String password) async {
    await session.callNoCheck('DynDNS', method: 'addHost', args: {
      'service': service,
      'hostname': hostname,
      'username': username,
      'password': password,
    });
  }

  @override
  Future<void> deleteDynDnsHost(String hostname) async {
    await session.callNoCheck('DynDNS', method: 'delHost', args: {'hostname': hostname});
  }

  @override
  Future<List<StaticRoute>> fetchStaticRoutes() async {
    final map = await _safeCallMap('NMC.LAN', method: 'getStaticRoutes');
    return map.entries.where((e) => e.value is Map).map((e) {
      final r = e.value as Map;
      return StaticRoute(
        id: e.key,
        destination: '${r['Dst'] ?? ''}/${r['DstLen'] ?? 24}',
        gateway: r['Gateway']?.toString() ?? '',
        interfaceName: r['Status']?.toString() ?? 'LAN',
      );
    }).toList();
  }

  @override
  Future<void> addStaticRoute(String destination, String gateway) async {
    final parts = destination.split('/');
    final dst = parts[0];
    final len = parts.length > 1 ? int.tryParse(parts[1]) ?? 24 : 24;
    await session.callNoCheck('NMC.LAN', method: 'addStaticRoute', args: {
      'Name': 'route_${DateTime.now().millisecondsSinceEpoch % 100000}',
      'Dst': dst,
      'DstLen': len,
      'Gateway': gateway,
      'Enable': true,
      'Priority': 3001,
    });
  }

  @override
  Future<void> deleteStaticRoute(String id) async {
    await session.callNoCheck('NMC.LAN', method: 'deleteStaticRoute', args: {'Name': id});
  }

  @override
  Future<void> triggerBackup() async {
    await session.callNoCheck('NMC.NetworkConfig', method: 'launchNetworkBackup', args: {'delay': true});
  }

  @override
  Future<void> triggerRestore() async {
    await session.callNoCheck('NMC.NetworkConfig', method: 'launchNetworkRestore');
  }

  @override
  Future<SpeedTestResult> runSpeedTest() async {
    final res = await _safeCallMap('SpeedTest', method: 'getWANResults');
    return SpeedTestResult(
      timestamp: DateTime.now(),
      downloadMbps: ((res['download'] as num?)?.toDouble() ?? 0) / 1000.0,
      uploadMbps: ((res['upload'] as num?)?.toDouble() ?? 0) / 1000.0,
      pingMs: (res['latency'] as num?)?.toDouble() ?? 0,
      server: 'Orange AutoDiag WAN',
    );
  }

  @override
  Future<String> executeRawApi(
      String service, String method, Map<String, dynamic> params) async {
    final res = await session.request(service, method: method, args: params);
    return const JsonEncoder.withIndent('  ').convert(res);
  }
}
