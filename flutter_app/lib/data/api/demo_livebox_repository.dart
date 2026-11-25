import 'dart:convert';
import 'dart:math';

import '../models/models.dart';
import 'livebox_repository.dart';

/// Rich, stateful, interactive Demo Mode repository simulating a Livebox 7 W7
/// with 14 devices, 2 Wi-Fi 6 repeaters, 1 UHD TV decoder, live traffic waves,
/// live events, and working CRUD across every single tab.
class DemoLiveboxRepository implements LiveboxRepository {
  final Random _rng = Random(42);
  int _tick = 0;
  int _eventSeq = 100;

  late LiveboxInfo _info;
  late List<NetworkInterfaceInfo> _interfaces;
  late List<NetworkDevice> _devices;
  late DhcpConfig _dhcpConfig;
  late List<DhcpBinding> _dhcpBindings;
  late List<NatPatRule> _natPatRules;
  late List<PtfRule> _ptfRules;
  late DmzConfig _dmz;
  late FirewallState _firewall;
  late List<PhoneCallEntry> _calls;
  late List<PhoneContact> _contacts;
  late List<RepeaterInfo> _repeaters;
  late List<TvDecoderInfo> _decoders;
  late List<WifiBandConfig> _wifiBands;
  late List<RebootEntry> _rebootHistory;
  late List<DynDnsHost> _dynDnsHosts;
  late List<StaticRoute> _staticRoutes;
  final List<LiveboxEvent> _pendingEvents = [];

  DemoLiveboxRepository() {
    _seedInitialState();
  }

  @override
  bool get isDemo => true;

  @override
  String get connectionLabel => 'Demo · Livebox 7 W7 (192.168.1.1)';

  @override
  Future<void> disconnect() async {}

  void _seedInitialState() {
    final now = DateTime.now();

    _info = const LiveboxInfo(
      modelName: 'Livebox 7 W7',
      productClass: 'Livebox W7',
      manufacturer: 'Sagemcom',
      serialNumber: 'LK25148DP904218',
      hardwareVersion: 'SG_LBW7_1.2.1',
      softwareVersion: 'SG70_sip-fr-5.24.18.1',
      macAddress: 'F8:87:C6:19:30:2F',
      uptimeSeconds: 14 * 86400 + 6 * 3600 + 42 * 60,
      memoryTotalKb: 1048576,
      memoryFreeKb: 412640,
      linkType: 'XGS-PON',
      linkState: 'up',
      wanStatus: 'up',
      wanIpv4: '90.114.228.47',
      wanIpv6: '2a01:cb08:8a42:e900::1',
      wanIpv6Prefix: '2a01:cb08:8a42:e900::/56',
      wanGateway: '193.253.160.3',
      dnsServers: ['80.10.246.1', '81.253.149.9'],
      maxDownBitrateMbps: 8000,
      maxUpBitrateMbps: 8000,
      ontModel: 'Sagemcom XGS-PON Integrated',
      ontSerial: 'SMBS04A19302',
      opticalRxPowerDbm: -17.84,
      opticalTxPowerDbm: 4.12,
      opticalTempC: 44.5,
      opticalVoltageV: 3.29,
      lanIp: '192.168.1.1',
      lanMask: '255.255.255.0',
      wifiEnabled: true,
      guestWifiEnabled: false,
      wifiSchedulerEnabled: true,
      voipRegistered: true,
      voipNumber: '+33 1 42 68 53 09',
      iptvEnabled: true,
      usbDeviceCount: 1,
      orangeLedLevel: 180,
      showWifiPasswordOnScreen: false,
    );

    _interfaces = [
      const NetworkInterfaceInfo(
        key: 'veip0',
        name: 'Fiber XGS-PON',
        type: 'wan',
        enabled: true,
        up: true,
        speedMbps: 10000,
        rxBytes: 1847293041200,
        txBytes: 392841293400,
        rxBytesPerSec: 18500000,
        txBytesPerSec: 4200000,
      ),
      const NetworkInterfaceInfo(
        key: 'ETH0',
        name: 'Ethernet 10G',
        type: 'eth',
        enabled: true,
        up: true,
        speedMbps: 10000,
        rxBytes: 842103492100,
        txBytes: 210482931000,
        rxBytesPerSec: 11200000,
        txBytesPerSec: 2800000,
      ),
      const NetworkInterfaceInfo(
        key: 'ETH1',
        name: 'Ethernet 1',
        type: 'eth',
        enabled: true,
        up: true,
        speedMbps: 1000,
        rxBytes: 294102938400,
        txBytes: 41203948100,
        rxBytesPerSec: 2400000,
        txBytesPerSec: 450000,
      ),
      const NetworkInterfaceInfo(
        key: 'ETH2',
        name: 'Ethernet 2',
        type: 'eth',
        enabled: true,
        up: true,
        speedMbps: 1000,
        rxBytes: 98412039400,
        txBytes: 12039481200,
        rxBytesPerSec: 650000,
        txBytesPerSec: 120000,
      ),
      const NetworkInterfaceInfo(
        key: 'ETH3',
        name: 'Ethernet 3',
        type: 'eth',
        enabled: true,
        up: false,
        speedMbps: 0,
        rxBytes: 0,
        txBytes: 0,
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
      ),
      const NetworkInterfaceInfo(
        key: 'vap5g0priv',
        name: 'Wi-Fi 5 GHz (MLO)',
        type: 'wif',
        enabled: true,
        up: true,
        speedMbps: 4800,
        channel: 100,
        band: '5 GHz',
        ssid: 'Livebox-W7-Home',
        securityMode: 'WPA3-Personal',
        rxBytes: 512938471200,
        txBytes: 109482716200,
        rxBytesPerSec: 3900000,
        txBytesPerSec: 780000,
      ),
      const NetworkInterfaceInfo(
        key: 'vap2g0priv',
        name: 'Wi-Fi 2.4 GHz',
        type: 'wif',
        enabled: true,
        up: true,
        speedMbps: 688,
        channel: 6,
        band: '2.4 GHz',
        ssid: 'Livebox-W7-Home',
        securityMode: 'WPA2/WPA3',
        rxBytes: 74920193800,
        txBytes: 18492019300,
        rxBytesPerSec: 350000,
        txBytesPerSec: 90000,
      ),
      const NetworkInterfaceInfo(
        key: 'vap5g0guest',
        name: 'Guest Wi-Fi',
        type: 'gwi',
        enabled: false,
        up: false,
        speedMbps: 0,
        channel: 100,
        band: '5 GHz',
        ssid: 'Livebox-W7-Guest',
        securityMode: 'WPA2-Personal',
        rxBytes: 482019300,
        txBytes: 91203400,
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
      ),
    ];

    _devices = [
      NetworkDevice(
        key: 'A4:83:E7:2B:91:04',
        name: 'MacBook Pro M4 Max',
        liveboxName: 'MacBook-Pro',
        dnsName: 'macbook-pro.home',
        deviceType: 'Laptop iOS',
        vendor: 'Apple, Inc.',
        ipAddress: '192.168.1.12',
        ipv6Address: '2a01:cb08:8a42:e900::12',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'vap5g0priv',
        interfaceName: 'Wi-Fi 5 GHz',
        linkType: 'wifi5',
        rssi: -46,
        linkSpeedMbps: 2401,
        rxBytes: 184920192830,
        txBytes: 62019384710,
        rxBytesPerSec: 2150000,
        txBytesPerSec: 640000,
        firstSeen: now.subtract(const Duration(days: 120)),
        lastChanged: now.subtract(const Duration(minutes: 4)),
        tags: const ['lan', 'wifi', 'ipv4', 'ipv6', 'dhcp', 'ssw_sta'],
      ),
      NetworkDevice(
        key: '00:11:32:DC:84:1A',
        name: 'Synology DS923+ NAS',
        liveboxName: 'DiskStation',
        dnsName: 'nas.home',
        deviceType: 'NAS',
        vendor: 'Synology Incorporated',
        ipAddress: '192.168.1.10',
        ipv6Address: '2a01:cb08:8a42:e900::10',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH0',
        interfaceName: 'Eth 10G',
        linkType: 'eth',
        linkSpeedMbps: 10000,
        rxBytes: 682910384900,
        txBytes: 198472910200,
        rxBytesPerSec: 8400000,
        txBytesPerSec: 2300000,
        firstSeen: now.subtract(const Duration(days: 340)),
        lastChanged: now.subtract(const Duration(hours: 12)),
        tags: const ['lan', 'eth', 'ipv4', 'ipv6', 'static'],
      ),
      NetworkDevice(
        key: 'D8:BB:C1:44:7F:92',
        name: 'Workstation Linux',
        liveboxName: 'arch-dev',
        dnsName: 'workstation.home',
        deviceType: 'Desktop Linux',
        vendor: 'Micro-Star INTL CO.',
        ipAddress: '192.168.1.15',
        ipv6Address: '2a01:cb08:8a42:e900::15',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH0',
        interfaceName: 'Eth 10G',
        linkType: 'eth',
        linkSpeedMbps: 2500,
        rxBytes: 249102938400,
        txBytes: 91203948100,
        rxBytesPerSec: 2800000,
        txBytesPerSec: 520000,
        firstSeen: now.subtract(const Duration(days: 210)),
        lastChanged: now.subtract(const Duration(minutes: 18)),
        tags: const ['lan', 'eth', 'ipv4', 'ipv6'],
      ),
      NetworkDevice(
        key: '6C:72:E7:99:11:3B',
        name: 'iPhone 16 Pro',
        liveboxName: 'iPhone-Camille',
        dnsName: 'iphone-camille.home',
        deviceType: 'Mobile iOS',
        vendor: 'Apple, Inc.',
        ipAddress: '192.168.1.21',
        ipv6Address: '2a01:cb08:8a42:e900::21',
        active: true,
        blocked: false,
        staticIp: false,
        interfaceKey: 'vap5g0priv',
        interfaceName: 'Wi-Fi 5 GHz',
        linkType: 'wifi5',
        rssi: -52,
        linkSpeedMbps: 1729,
        rxBytes: 42910293800,
        txBytes: 8492019300,
        rxBytesPerSec: 920000,
        txBytesPerSec: 180000,
        firstSeen: now.subtract(const Duration(days: 65)),
        lastChanged: now.subtract(const Duration(minutes: 2)),
        tags: const ['lan', 'wifi', 'ipv4', 'ipv6', 'ssw_sta'],
      ),
      NetworkDevice(
        key: 'E4:5F:01:6A:2C:88',
        name: 'Home Assistant',
        liveboxName: 'homeassistant',
        dnsName: 'hass.home',
        deviceType: 'Desktop Linux',
        vendor: 'Raspberry Pi Trading',
        ipAddress: '192.168.1.20',
        ipv6Address: '2a01:cb08:8a42:e900::20',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH1',
        interfaceName: 'Eth 1',
        linkType: 'eth',
        linkSpeedMbps: 1000,
        rxBytes: 18492019300,
        txBytes: 9182736400,
        rxBytesPerSec: 180000,
        txBytesPerSec: 95000,
        firstSeen: now.subtract(const Duration(days: 400)),
        lastChanged: now.subtract(const Duration(days: 14)),
        tags: const ['lan', 'eth', 'ipv4', 'static'],
      ),
      NetworkDevice(
        key: 'BC:99:11:A2:44:0C',
        name: 'Orange TV UHD 4K',
        liveboxName: 'Decodeur-TV-UHD',
        dnsName: 'tv-uhd.home',
        deviceType: 'Set-top Box TV UHD',
        vendor: 'Sagemcom Broadband SAS',
        ipAddress: '192.168.1.30',
        ipv6Address: '2a01:cb08:8a42:e900::30',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH1',
        interfaceName: 'Eth 1',
        linkType: 'eth',
        linkSpeedMbps: 1000,
        rxBytes: 312938471200,
        txBytes: 4829102900,
        rxBytesPerSec: 1950000,
        txBytesPerSec: 45000,
        firstSeen: now.subtract(const Duration(days: 280)),
        lastChanged: now.subtract(const Duration(hours: 2)),
        tags: const ['lan', 'eth', 'stb', 'iptv'],
      ),
      NetworkDevice(
        key: '70:5A:0F:E1:33:90',
        name: 'Samsung QLED 65"',
        liveboxName: 'Samsung-TV',
        dnsName: 'samsung-tv.home',
        deviceType: 'TV',
        vendor: 'Samsung Electronics',
        ipAddress: '192.168.1.31',
        ipv6Address: '2a01:cb08:8a42:e900::31',
        active: true,
        blocked: false,
        staticIp: false,
        interfaceKey: 'vap5g0priv',
        interfaceName: 'Wi-Fi 5 GHz',
        linkType: 'wifi5',
        rssi: -61,
        linkSpeedMbps: 866,
        rxBytes: 129482716200,
        txBytes: 2910394800,
        rxBytesPerSec: 1400000,
        txBytesPerSec: 32000,
        firstSeen: now.subtract(const Duration(days: 190)),
        lastChanged: now.subtract(const Duration(minutes: 45)),
        tags: const ['lan', 'wifi', 'tv', 'upnp'],
      ),
      NetworkDevice(
        key: '2C:CC:44:8F:12:D1',
        name: 'PlayStation 5 Pro',
        liveboxName: 'PS5-LivingRoom',
        dnsName: 'ps5.home',
        deviceType: 'Game Console',
        vendor: 'Sony Interactive Ent.',
        ipAddress: '192.168.1.35',
        ipv6Address: '2a01:cb08:8a42:e900::35',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH2',
        interfaceName: 'Eth 2',
        linkType: 'eth',
        linkSpeedMbps: 1000,
        rxBytes: 421938471200,
        txBytes: 18492019300,
        rxBytesPerSec: 650000,
        txBytesPerSec: 120000,
        firstSeen: now.subtract(const Duration(days: 90)),
        lastChanged: now.subtract(const Duration(hours: 1)),
        tags: const ['lan', 'eth', 'upnp'],
      ),
      NetworkDevice(
        key: '90:09:D0:55:AA:10',
        name: 'Repeater Salon (Wi-Fi 6)',
        liveboxName: 'Repeteur-Salon',
        dnsName: 'repeater-salon.home',
        deviceType: 'repeteurwifi6',
        vendor: 'Sercomm Corp.',
        ipAddress: '192.168.1.40',
        ipv6Address: '2a01:cb08:8a42:e900::40',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH2',
        interfaceName: 'Eth 2',
        linkType: 'eth',
        linkSpeedMbps: 1000,
        rxBytes: 98120394800,
        txBytes: 24910293800,
        rxBytesPerSec: 420000,
        txBytesPerSec: 110000,
        firstSeen: now.subtract(const Duration(days: 260)),
        lastChanged: now.subtract(const Duration(days: 14)),
        tags: const ['lan', 'eth', 'ssw_ap'],
      ),
      NetworkDevice(
        key: '90:09:D0:55:BB:22',
        name: 'Repeater Bureau (Wi-Fi 6)',
        liveboxName: 'Repeteur-Bureau',
        dnsName: 'repeater-bureau.home',
        deviceType: 'repeteurwifi6',
        vendor: 'Sercomm Corp.',
        ipAddress: '192.168.1.41',
        ipv6Address: '2a01:cb08:8a42:e900::41',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'vap5g0priv',
        interfaceName: 'Wi-Fi 5 GHz',
        linkType: 'wifi5',
        rssi: -58,
        linkSpeedMbps: 1921,
        rxBytes: 54920193800,
        txBytes: 12910293800,
        rxBytesPerSec: 310000,
        txBytesPerSec: 75000,
        firstSeen: now.subtract(const Duration(days: 180)),
        lastChanged: now.subtract(const Duration(days: 6)),
        tags: const ['lan', 'wifi', 'ssw_ap'],
      ),
      NetworkDevice(
        key: '00:17:88:71:9E:45',
        name: 'Philips Hue Bridge',
        liveboxName: 'Philips-hue',
        dnsName: 'hue.home',
        deviceType: 'Color Bulb',
        vendor: 'Signify B.V.',
        ipAddress: '192.168.1.50',
        ipv6Address: '',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'ETH1',
        interfaceName: 'Eth 1',
        linkType: 'eth',
        linkSpeedMbps: 100,
        rxBytes: 1293847100,
        txBytes: 982736400,
        rxBytesPerSec: 4200,
        txBytesPerSec: 3100,
        firstSeen: now.subtract(const Duration(days: 410)),
        lastChanged: now.subtract(const Duration(days: 14)),
        tags: const ['lan', 'eth', 'iot'],
      ),
      NetworkDevice(
        key: '48:A2:E6:31:77:0F',
        name: 'Garden IP Camera',
        liveboxName: 'Reolink-Cam-01',
        dnsName: 'cam-garden.home',
        deviceType: 'IP Camera',
        vendor: 'Reolink Innovation',
        ipAddress: '192.168.1.55',
        ipv6Address: '',
        active: true,
        blocked: false,
        staticIp: true,
        interfaceKey: 'vap2g0priv',
        interfaceName: 'Wi-Fi 2.4 GHz',
        linkType: 'wifi24',
        rssi: -71,
        linkSpeedMbps: 144,
        rxBytes: 4201938400,
        txBytes: 68291038400,
        rxBytesPerSec: 25000,
        txBytesPerSec: 540000,
        firstSeen: now.subtract(const Duration(days: 130)),
        lastChanged: now.subtract(const Duration(hours: 5)),
        tags: const ['lan', 'wifi', 'iot'],
      ),
      NetworkDevice(
        key: 'F0:18:98:4C:22:7A',
        name: 'iPad Air Kids',
        liveboxName: 'iPad-Leo',
        dnsName: 'ipad-leo.home',
        deviceType: 'Tablet iOS',
        vendor: 'Apple, Inc.',
        ipAddress: '192.168.1.62',
        ipv6Address: '2a01:cb08:8a42:e900::62',
        active: false,
        blocked: true,
        staticIp: false,
        interfaceKey: 'vap5g0priv',
        interfaceName: 'Wi-Fi 5 GHz',
        linkType: 'wifi5',
        rssi: -67,
        linkSpeedMbps: 866,
        rxBytes: 28192039400,
        txBytes: 3102938400,
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
        firstSeen: now.subtract(const Duration(days: 150)),
        lastChanged: now.subtract(const Duration(hours: 3)),
        tags: const ['lan', 'wifi', 'tod_blocked'],
      ),
      NetworkDevice(
        key: '38:9D:92:1B:88:E0',
        name: 'Epson EcoTank Printer',
        liveboxName: 'EPSON-ET4850',
        dnsName: 'printer.home',
        deviceType: 'Printer',
        vendor: 'Seiko Epson Corp.',
        ipAddress: '192.168.1.70',
        ipv6Address: '',
        active: false,
        blocked: false,
        staticIp: true,
        interfaceKey: 'vap2g0priv',
        interfaceName: 'Wi-Fi 2.4 GHz',
        linkType: 'wifi24',
        rssi: -64,
        linkSpeedMbps: 72,
        rxBytes: 612938400,
        txBytes: 184920100,
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
        firstSeen: now.subtract(const Duration(days: 300)),
        lastChanged: now.subtract(const Duration(days: 2)),
        tags: const ['lan', 'wifi'],
      ),
    ];

    _dhcpConfig = const DhcpConfig(
      enabled: true,
      lanIp: '192.168.1.1',
      subnetMask: '255.255.255.0',
      minAddress: '192.168.1.10',
      maxAddress: '192.168.1.150',
      leaseTimeSeconds: 86400,
      dhcpv6Enabled: true,
      ipv6Prefix: '2a01:cb08:8a42:e900::/56',
    );

    _dhcpBindings = _devices
        .map((d) => DhcpBinding(
              macAddress: d.key,
              ipAddress: d.ipAddress,
              deviceName: d.name,
              isStatic: d.staticIp,
              active: d.active,
              domain: 'default',
            ))
        .toList();

    _natPatRules = [
      const NatPatRule(
        id: 'webui_https_nas',
        name: 'Synology HTTPS Reverse Proxy',
        type: 'IPv4',
        enabled: true,
        protocol: 'TCP',
        externalPort: '443',
        internalPort: '443',
        destinationIp: '192.168.1.10',
        externalIps: 'All',
        description: 'Synology HTTPS Reverse Proxy',
      ),
      const NatPatRule(
        id: 'webui_wireguard',
        name: 'WireGuard VPN',
        type: 'IPv4',
        enabled: true,
        protocol: 'UDP',
        externalPort: '51820',
        internalPort: '51820',
        destinationIp: '192.168.1.20',
        externalIps: 'All',
        description: 'Home Assistant WireGuard Tunnel',
      ),
      const NatPatRule(
        id: 'webui_ssh_dev',
        name: 'Dev Workstation SSH',
        type: 'IPv4',
        enabled: false,
        protocol: 'TCP',
        externalPort: '2222',
        internalPort: '22',
        destinationIp: '192.168.1.15',
        externalIps: '82.64.0.0/16',
        description: 'Restricted SSH access',
      ),
      const NatPatRule(
        id: 'upnp_ps5',
        name: 'PlayStation Network (UPnP)',
        type: 'UPnP',
        enabled: true,
        protocol: 'UDP',
        externalPort: '9308',
        internalPort: '9308',
        destinationIp: '192.168.1.35',
        externalIps: 'All',
        description: 'Auto-created via UPnP IGD',
      ),
    ];

    _ptfRules = [
      const PtfRule(
        id: 'ptf_ipsec',
        name: 'IPsec ESP Passthrough',
        enabled: true,
        protocol: 'ESP',
        destinationIp: '192.168.1.10',
      ),
    ];

    _dmz = const DmzConfig(enabled: false, destinationIp: '');

    _firewall = const FirewallState(
      ipv4Level: 'Medium',
      ipv6Level: 'Medium',
      respondToPingIpv4: false,
      respondToPingIpv6: true,
      rules: [
        FirewallRule(
          id: 'fw_allow_wg',
          enabled: true,
          isIpv6: false,
          action: 'Accept',
          protocol: 'UDP',
          sourcePrefix: '0.0.0.0/0',
          sourcePort: '',
          destinationPrefix: '192.168.1.20',
          destinationPort: '51820',
          description: 'Allow WireGuard inbound',
        ),
        FirewallRule(
          id: 'fw_block_cam_wan',
          enabled: true,
          isIpv6: false,
          action: 'Drop',
          protocol: 'All',
          sourcePrefix: '192.168.1.55',
          sourcePort: '',
          destinationPrefix: '0.0.0.0/0',
          destinationPort: '',
          description: 'Isolate IP Camera from WAN',
        ),
        FirewallRule(
          id: 'fw_allow_v6_https',
          enabled: true,
          isIpv6: true,
          action: 'Accept',
          protocol: 'TCP',
          sourcePrefix: '::/0',
          sourcePort: '',
          destinationPrefix: '2a01:cb08:8a42:e900::10',
          destinationPort: '443',
          description: 'IPv6 HTTPS to NAS',
        ),
      ],
    );

    _calls = [
      PhoneCallEntry(
        id: 'call_1',
        type: CallType.incoming,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 14)),
        number: '+33 6 14 82 91 05',
        contactName: 'Camille Laurent',
        durationSeconds: 342,
      ),
      PhoneCallEntry(
        id: 'call_2',
        type: CallType.missed,
        timestamp: now.subtract(const Duration(hours: 5, minutes: 40)),
        number: '+33 1 62 44 19 80',
        contactName: 'Suspected Telemarketer',
        durationSeconds: 0,
        isSpam: true,
      ),
      PhoneCallEntry(
        id: 'call_3',
        type: CallType.outgoing,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        number: '+33 1 45 20 88 12',
        contactName: 'Cabinet Médical',
        durationSeconds: 185,
      ),
      PhoneCallEntry(
        id: 'call_4',
        type: CallType.incoming,
        timestamp: now.subtract(const Duration(days: 2, hours: 7)),
        number: '+33 6 77 32 10 49',
        contactName: 'Julien Martin',
        durationSeconds: 618,
      ),
      PhoneCallEntry(
        id: 'call_5',
        type: CallType.failed,
        timestamp: now.subtract(const Duration(days: 3, hours: 1)),
        number: '+33 9 72 11 40 00',
        contactName: 'Support Technique',
        durationSeconds: 0,
      ),
    ];

    _contacts = [
      PhoneContact(
        id: 'ct_1',
        firstName: 'Camille',
        lastName: 'Laurent',
        cellNumber: '+33 6 14 82 91 05',
        homeNumber: '+33 1 42 68 53 09',
        ringtone: '2',
      ),
      PhoneContact(
        id: 'ct_2',
        firstName: 'Julien',
        lastName: 'Martin',
        cellNumber: '+33 6 77 32 10 49',
        workNumber: '+33 1 53 90 22 14',
        ringtone: '1',
      ),
      PhoneContact(
        id: 'ct_3',
        firstName: 'Cabinet',
        lastName: 'Médical',
        workNumber: '+33 1 45 20 88 12',
        ringtone: '3',
      ),
    ];

    _repeaters = [
      RepeaterInfo(
        key: '90:09:D0:55:AA:10',
        name: 'Repeater Salon',
        model: 'Répéteur Wi-Fi 6 (Sercomm)',
        ipAddress: '192.168.1.40',
        softwareVersion: 'SG6R_sip-fr-2.18.4',
        active: true,
        uptimeSeconds: 14 * 86400 + 6 * 3600 + 39 * 60,
        backhaulType: 'Ethernet 1 Gbps',
        backhaulRssi: null,
        wifiEnabled: true,
        connectedDevicesCount: 4,
        connectedDeviceKeys: const ['70:5A:0F:E1:33:90', '6C:72:E7:99:11:3B'],
        rebootHistory: [
          RebootEntry(
            bootDate: now.subtract(const Duration(days: 14, hours: 6)),
            bootReason: 'Firmware Upgrade',
            shutdownDate: now.subtract(const Duration(days: 14, hours: 6, minutes: 2)),
            shutdownReason: 'Upgrade Reboot',
          ),
        ],
      ),
      RepeaterInfo(
        key: '90:09:D0:55:BB:22',
        name: 'Repeater Bureau',
        model: 'Répéteur Wi-Fi 6 (Sercomm)',
        ipAddress: '192.168.1.41',
        softwareVersion: 'SG6R_sip-fr-2.18.4',
        active: true,
        uptimeSeconds: 6 * 86400 + 11 * 3600 + 15 * 60,
        backhaulType: 'Wi-Fi 5 GHz Mesh',
        backhaulRssi: -58,
        wifiEnabled: true,
        connectedDevicesCount: 3,
        connectedDeviceKeys: const ['A4:83:E7:2B:91:04', '48:A2:E6:31:77:0F'],
        rebootHistory: [
          RebootEntry(
            bootDate: now.subtract(const Duration(days: 6, hours: 11)),
            bootReason: 'GUI_Reboot',
            shutdownDate: now.subtract(const Duration(days: 6, hours: 11, minutes: 1)),
            shutdownReason: 'User Requested',
          ),
        ],
      ),
    ];

    _decoders = [
      TvDecoderInfo(
        key: 'BC:99:11:A2:44:0C',
        name: 'Décodeur TV UHD 4K (Salon)',
        model: 'Sagemcom UHD 4K (IHD92)',
        ipAddress: '192.168.1.30',
        active: true,
        standby: false,
        mediaType: 'LIVE',
        mediaState: 'PLAY',
        channelName: 'France 2 UHD',
        channelNumber: 2,
        currentProgram: 'Journal 20h · 4K HDR10',
      ),
    ];

    _wifiBands = [
      WifiBandConfig(
        key: 'vap2g0priv',
        band: '2.4 GHz',
        enabled: true,
        ssid: 'Livebox-W7-Home',
        broadcastSsid: true,
        securityMode: 'WPA2/WPA3-Personal',
        channel: 'Auto (6)',
        bandwidth: '20/40 MHz',
        macFiltering: false,
      ),
      WifiBandConfig(
        key: 'vap5g0priv',
        band: '5 GHz (Wi-Fi 7 MLO)',
        enabled: true,
        ssid: 'Livebox-W7-Home',
        broadcastSsid: true,
        securityMode: 'WPA3-Personal',
        channel: 'Auto (100)',
        bandwidth: '160 MHz',
        macFiltering: false,
      ),
      WifiBandConfig(
        key: 'vap5g0guest',
        band: 'Guest 2.4 / 5 GHz',
        enabled: false,
        ssid: 'Livebox-W7-Guest',
        broadcastSsid: true,
        securityMode: 'WPA2-Personal',
        channel: 'Auto (100)',
        bandwidth: '80 MHz',
        macFiltering: false,
      ),
    ];

    _rebootHistory = [
      RebootEntry(
        bootDate: now.subtract(const Duration(days: 14, hours: 6)),
        bootReason: 'Firmware Upgrade',
        shutdownDate: now.subtract(const Duration(days: 14, hours: 6, minutes: 3)),
        shutdownReason: 'Planned Update',
      ),
      RebootEntry(
        bootDate: now.subtract(const Duration(days: 42, hours: 18)),
        bootReason: 'GUI_Reboot',
        shutdownDate: now.subtract(const Duration(days: 42, hours: 18, minutes: 2)),
        shutdownReason: 'User Initiated',
      ),
      RebootEntry(
        bootDate: now.subtract(const Duration(days: 89, hours: 4)),
        bootReason: 'PowerLoss',
        shutdownDate: null,
        shutdownReason: 'Unexpected Power Cut',
      ),
    ];

    _dynDnsHosts = [
      DynDnsHost(
        service: 'no-ip',
        hostname: 'myhome-lab.ddns.net',
        username: 'homelab_user',
        status: 'Updated',
        lastUpdate: now.subtract(const Duration(hours: 3)),
      ),
    ];

    _staticRoutes = [
      StaticRoute(
        id: 'rt_vlan20',
        destination: '10.20.0.0/24',
        gateway: '192.168.1.10',
        interfaceName: 'Bound (LAN)',
      ),
    ];

    // Seed initial historical events so Events screen is immediately informative
    _pendingEvents.addAll([
      LiveboxEvent(
        id: 'ev_1',
        timestamp: now.subtract(const Duration(minutes: 14)),
        deviceKey: 'A4:83:E7:2B:91:04',
        deviceName: 'MacBook Pro M4 Max',
        reason: 'device_updated',
        summary: 'Wi-Fi steering: band 5GHz MLO (RSSI -46 dBm, 2401 Mbps)',
        rawPayload: const {
          'handler': 'Devices.Device.A4:83:E7:2B:91:04',
          'object': {'reason': 'wifi_device_updated', 'SignalStrength': -46, 'OperatingFrequencyBand': '5GHz'},
        },
      ),
      LiveboxEvent(
        id: 'ev_2',
        timestamp: now.subtract(const Duration(minutes: 8)),
        deviceKey: '6C:72:E7:99:11:3B',
        deviceName: 'iPhone 16 Pro',
        reason: 'Active',
        summary: 'Device came online via Wi-Fi 5 GHz (192.168.1.21)',
        rawPayload: const {
          'handler': 'Devices.Device.6C:72:E7:99:11:3B',
          'object': {'reason': 'changed', 'Active': true, 'IPAddress': '192.168.1.21'},
        },
      ),
      LiveboxEvent(
        id: 'ev_3',
        timestamp: now.subtract(const Duration(minutes: 3)),
        deviceKey: 'LIVEBOX',
        deviceName: 'Livebox 7 W7',
        reason: 'Firewall',
        summary: 'UPnP IGD lease refreshed for 192.168.1.35:9308/UDP',
        rawPayload: const {
          'handler': 'Firewall.PortForwarding.upnp_ps5',
          'object': {'reason': 'changed', 'DestinationIPAddress': '192.168.1.35', 'ExternalPort': '9308'},
        },
      ),
    ]);
  }

  void _pushDemoEvent(String deviceKey, String deviceName, String reason, String summary) {
    _pendingEvents.add(LiveboxEvent(
      id: 'ev_${++_eventSeq}',
      timestamp: DateTime.now(),
      deviceKey: deviceKey,
      deviceName: deviceName,
      reason: reason,
      summary: summary,
      rawPayload: {
        'handler': deviceKey == 'LIVEBOX' ? 'NMC' : 'Devices.Device.$deviceKey',
        'object': {'reason': reason, 'summary': summary},
      },
    ));
  }

  @override
  Future<LiveboxInfo> fetchLiveboxInfo() async {
    _info = _info.copyWith(uptimeSeconds: _info.uptimeSeconds + 2);
    return _info;
  }

  @override
  Future<List<NetworkInterfaceInfo>> fetchInterfaces() async => List.of(_interfaces);

  @override
  Future<List<NetworkDevice>> fetchDevices() async => List.of(_devices);

  @override
  Future<void> renameDevice(String mac, String newName) async {
    final idx = _devices.indexWhere((d) => d.key == mac);
    if (idx != -1) {
      final old = _devices[idx];
      _devices[idx] = old.copyWith(name: newName, liveboxName: newName);
      _pushDemoEvent(mac, newName, 'device_name_changed', 'Renamed from "${old.name}" to "$newName"');
    }
  }

  @override
  Future<void> setDeviceType(String mac, String newType) async {
    final idx = _devices.indexWhere((d) => d.key == mac);
    if (idx != -1) {
      final old = _devices[idx];
      _devices[idx] = old.copyWith(deviceType: newType);
      _pushDemoEvent(mac, old.name, 'device_updated', 'Device type changed to $newType');
    }
  }

  @override
  Future<void> setDeviceBlocked(String mac, bool blocked) async {
    final idx = _devices.indexWhere((d) => d.key == mac);
    if (idx != -1) {
      final old = _devices[idx];
      _devices[idx] = old.copyWith(blocked: blocked);
      _pushDemoEvent(
        mac,
        old.name,
        blocked ? 'Access Blocked' : 'Access Restored',
        blocked ? 'WAN access disabled via ToD Scheduler' : 'WAN access restored',
      );
    }
  }

  @override
  Future<void> wakeOnLan(String mac) async {
    final idx = _devices.indexWhere((d) => d.key == mac);
    if (idx != -1) {
      final old = _devices[idx];
      _devices[idx] = old.copyWith(active: true, lastChanged: DateTime.now());
      _pushDemoEvent(mac, old.name, 'WOL', 'Magic packet broadcast sent to $mac');
    }
  }

  @override
  Future<void> deleteDevice(String mac) async {
    final match = _devices.where((d) => d.key == mac).firstOrNull;
    _devices.removeWhere((d) => d.key == mac);
    if (match != null) {
      _pushDemoEvent(mac, match.name, 'device_deleted', 'Removed from Livebox known devices');
    }
  }

  @override
  Future<Map<String, TrafficSample>> sampleTraffic(List<String> interfaceKeys) async {
    _tick++;
    final now = DateTime.now();
    final out = <String, TrafficSample>{};

    // Smooth realistic traffic waves with occasional bursts
    final wave = sin(_tick * 0.35) * 45 + cos(_tick * 0.14) * 28;
    final burst = (_tick % 11 == 0) ? 140.0 + _rng.nextDouble() * 90 : 0.0;

    for (final key in interfaceKeys) {
      double scale = 1.0;
      if (key == 'ETH0') scale = 0.62;
      if (key == 'ETH1') scale = 0.18;
      if (key == 'ETH2') scale = 0.09;
      if (key == 'vap5g0priv') scale = 0.34;
      if (key == 'vap2g0priv') scale = 0.05;
      if (key == 'vap5g0guest') scale = _info.guestWifiEnabled ? 0.04 : 0.0;

      final down = max(0.0, (135 + wave + burst + _rng.nextDouble() * 22) * scale);
      final up = max(0.0, (32 + wave * 0.25 + burst * 0.18 + _rng.nextDouble() * 8) * scale);
      out[key] = TrafficSample(timestamp: now, downMbps: down, upMbps: up);

      final idx = _interfaces.indexWhere((i) => i.key == key);
      if (idx != -1) {
        final cur = _interfaces[idx];
        _interfaces[idx] = cur.copyWith(
          rxBytes: cur.rxBytes + (down * 125000).toInt(),
          txBytes: cur.txBytes + (up * 125000).toInt(),
          rxBytesPerSec: down * 125000,
          txBytesPerSec: up * 125000,
        );
      }
    }

    // Periodically emit a realistic ambient event
    if (_tick % 8 == 0) {
      final wifiDevs = _devices.where((d) => d.isWifi && d.active).toList();
      if (wifiDevs.isNotEmpty) {
        final d = wifiDevs[_rng.nextInt(wifiDevs.length)];
        final newRssi = (d.rssi ?? -55) + _rng.nextInt(5) - 2;
        _pushDemoEvent(
          d.key,
          d.name,
          'Statistics',
          'Wi-Fi link telemetry updated: RSSI $newRssi dBm, ${d.linkSpeedMbps ?? 866} Mbps',
        );
      }
    }

    return out;
  }

  @override
  Future<Map<String, DeviceTrafficStats>> sampleDeviceTraffic(
      List<NetworkInterfaceInfo> interfaces) async {
    final out = <String, DeviceTrafficStats>{};
    for (int i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (!d.isActiveWithIp) {
        out[d.key] = DeviceTrafficStats(
          rxBytes: d.rxBytes,
          txBytes: d.txBytes,
          rxBytesPerSec: 0,
          txBytesPerSec: 0,
        );
        continue;
      }
      final factor = 0.75 + _rng.nextDouble() * 0.55;
      final rxRate = max(0.0, d.rxBytesPerSec * factor);
      final txRate = max(0.0, d.txBytesPerSec * factor);
      final newRx = d.rxBytes + (rxRate * 2).toInt();
      final newTx = d.txBytes + (txRate * 2).toInt();
      _devices[i] = d.copyWith(
        rxBytes: newRx,
        txBytes: newTx,
        rxBytesPerSec: rxRate,
        txBytesPerSec: txRate,
      );
      out[d.key] = DeviceTrafficStats(
        rxBytes: newRx,
        txBytes: newTx,
        rxBytesPerSec: rxRate,
        txBytesPerSec: txRate,
      );
    }
    return out;
  }

  @override
  Future<List<LiveboxEvent>> pollEvents() async {
    if (_pendingEvents.isEmpty) return [];
    final copy = List<LiveboxEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    return copy;
  }

  @override
  Future<DhcpConfig> fetchDhcpConfig() async => _dhcpConfig;

  @override
  Future<void> saveDhcpConfig(DhcpConfig config) async {
    _dhcpConfig = config;
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'DHCP', 'DHCP pool updated (${config.minAddress} - ${config.maxAddress})');
  }

  @override
  Future<List<DhcpBinding>> fetchDhcpBindings() async => List.of(_dhcpBindings);

  @override
  Future<void> addDhcpBinding(String mac, String ip) async {
    final norm = mac.toUpperCase();
    final idx = _dhcpBindings.indexWhere((b) => b.macAddress == norm);
    final dev = _devices.where((d) => d.key == norm).firstOrNull;
    final binding = DhcpBinding(
      macAddress: norm,
      ipAddress: ip,
      deviceName: dev?.name ?? norm,
      isStatic: true,
      active: dev?.active ?? true,
      domain: 'default',
    );
    if (idx != -1) {
      _dhcpBindings[idx] = binding;
    } else {
      _dhcpBindings.insert(0, binding);
    }
    final dIdx = _devices.indexWhere((d) => d.key == norm);
    if (dIdx != -1) {
      _devices[dIdx] = _devices[dIdx].copyWith(staticIp: true, ipAddress: ip);
    }
  }

  @override
  Future<void> deleteDhcpBinding(String mac) async {
    final norm = mac.toUpperCase();
    _dhcpBindings.removeWhere((b) => b.macAddress == norm && b.isStatic);
    final dIdx = _devices.indexWhere((d) => d.key == norm);
    if (dIdx != -1) {
      _devices[dIdx] = _devices[dIdx].copyWith(staticIp: false);
    }
  }

  @override
  Future<List<NatPatRule>> fetchNatPatRules() async => List.of(_natPatRules);

  @override
  Future<void> saveNatPatRule(NatPatRule rule) async {
    final idx = _natPatRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _natPatRules[idx] = rule;
    } else {
      _natPatRules.add(rule);
    }
  }

  @override
  Future<void> deleteNatPatRule(NatPatRule rule) async {
    _natPatRules.removeWhere((r) => r.id == rule.id);
  }

  @override
  Future<List<PtfRule>> fetchPtfRules() async => List.of(_ptfRules);

  @override
  Future<void> savePtfRule(PtfRule rule) async {
    final idx = _ptfRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _ptfRules[idx] = rule;
    } else {
      _ptfRules.add(rule);
    }
  }

  @override
  Future<void> deletePtfRule(String id) async {
    _ptfRules.removeWhere((r) => r.id == id);
  }

  @override
  Future<DmzConfig> fetchDmz() async => _dmz;

  @override
  Future<void> saveDmz(DmzConfig config) async {
    _dmz = config;
  }

  @override
  Future<FirewallState> fetchFirewall() async => _firewall;

  @override
  Future<void> setFirewallLevels(String ipv4Level, String ipv6Level) async {
    _firewall = _firewall.copyWith(ipv4Level: ipv4Level, ipv6Level: ipv6Level);
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Firewall', 'Levels set to IPv4=$ipv4Level, IPv6=$ipv6Level');
  }

  @override
  Future<void> setRespondToPing(bool ipv4, bool ipv6) async {
    _firewall = _firewall.copyWith(respondToPingIpv4: ipv4, respondToPingIpv6: ipv6);
  }

  @override
  Future<void> saveFirewallRule(FirewallRule rule) async {
    final rules = List<FirewallRule>.of(_firewall.rules);
    final idx = rules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      rules[idx] = rule;
    } else {
      rules.add(rule);
    }
    _firewall = _firewall.copyWith(rules: rules);
  }

  @override
  Future<void> deleteFirewallRule(String id) async {
    final rules = List<FirewallRule>.of(_firewall.rules)..removeWhere((r) => r.id == id);
    _firewall = _firewall.copyWith(rules: rules);
  }

  @override
  Future<List<PhoneCallEntry>> fetchCallLog() async => List.of(_calls);

  @override
  Future<void> deleteCall(String id) async {
    _calls.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> ringPhones() async {
    _pushDemoEvent('LIVEBOX', 'VoIP Line 1', 'Ring', 'Handset ring test triggered');
  }

  @override
  Future<List<PhoneContact>> fetchContacts() async => List.of(_contacts);

  @override
  Future<void> saveContact(PhoneContact contact) async {
    final idx = _contacts.indexWhere((c) => c.id == contact.id && contact.id.isNotEmpty);
    if (idx != -1) {
      _contacts[idx] = contact;
    } else {
      _contacts.add(PhoneContact(
        id: 'ct_${DateTime.now().millisecondsSinceEpoch}',
        firstName: contact.firstName,
        lastName: contact.lastName,
        cellNumber: contact.cellNumber,
        homeNumber: contact.homeNumber,
        workNumber: contact.workNumber,
        ringtone: contact.ringtone,
      ));
    }
  }

  @override
  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<RepeaterInfo>> fetchRepeaters() async => List.of(_repeaters);

  @override
  Future<void> setRepeaterWifi(String mac, bool enabled) async {
    final idx = _repeaters.indexWhere((r) => r.key == mac);
    if (idx != -1) {
      _repeaters[idx] = _repeaters[idx].copyWith(wifiEnabled: enabled);
    }
  }

  @override
  Future<void> rebootRepeater(String mac) async {
    final idx = _repeaters.indexWhere((r) => r.key == mac);
    if (idx != -1) {
      _repeaters[idx] = _repeaters[idx].copyWith(uptimeSeconds: 12);
      _pushDemoEvent(mac, _repeaters[idx].name, 'Reboot', 'Repeater reboot initiated');
    }
  }

  static const List<({int num, String name, String prog})> _demoChannels = [
    (num: 1, name: 'TF1 4K', prog: 'Cinéma du soir · UHD'),
    (num: 2, name: 'France 2 UHD', prog: 'Journal 20h · 4K HDR10'),
    (num: 3, name: 'France 3', prog: 'Des Racines & Des Ailes'),
    (num: 4, name: 'Canal+ UHD', prog: 'Match en Direct · Dolby Atmos'),
    (num: 5, name: 'France 5', prog: 'Échappées Belles'),
    (num: 6, name: 'M6', prog: 'Top Chef'),
    (num: 7, name: 'ARTE HD', prog: 'Documentaire Sciences'),
  ];

  @override
  Future<List<TvDecoderInfo>> fetchTvDecoders() async => List.of(_decoders);

  @override
  Future<TvDecoderInfo> sendTvRemoteKey(String decoderKey, int keyCode) async {
    final idx = _decoders.indexWhere((d) => d.key == decoderKey);
    if (idx == -1) return _decoders.first;
    var cur = _decoders[idx];

    if (keyCode == 116) {
      // POWER
      final nextStandby = !cur.standby;
      cur = cur.copyWith(
        standby: nextStandby,
        mediaType: nextStandby ? 'STANDBY' : 'LIVE',
        mediaState: nextStandby ? 'IDLE' : 'PLAY',
      );
    } else if (keyCode == 164) {
      // PLAY/PAUSE
      cur = cur.copyWith(mediaState: cur.mediaState == 'PLAY' ? 'PAUSE' : 'PLAY');
    } else if (keyCode == 402 || keyCode == 403) {
      // CH+ / CH-
      final curIdx = _demoChannels.indexWhere((c) => c.num == cur.channelNumber);
      final delta = keyCode == 402 ? 1 : -1;
      final next = _demoChannels[((curIdx == -1 ? 0 : curIdx) + delta) % _demoChannels.length];
      cur = cur.copyWith(
        standby: false,
        mediaType: 'LIVE',
        mediaState: 'PLAY',
        channelNumber: next.num,
        channelName: next.name,
        currentProgram: next.prog,
      );
    } else if (keyCode == 139) {
      cur = cur.copyWith(standby: false, mediaType: 'HOMEPAGE', mediaState: 'IDLE');
    }
    _decoders[idx] = cur;
    return cur;
  }

  @override
  Future<TvDecoderInfo> zapTvChannel(
      String decoderKey, int channelNumber, String channelName) async {
    final idx = _decoders.indexWhere((d) => d.key == decoderKey);
    if (idx == -1) return _decoders.first;
    final found = _demoChannels.where((c) => c.num == channelNumber).firstOrNull;
    final updated = _decoders[idx].copyWith(
      standby: false,
      mediaType: 'LIVE',
      mediaState: 'PLAY',
      channelNumber: channelNumber,
      channelName: found?.name ?? channelName,
      currentProgram: found?.prog ?? 'Live Broadcast',
    );
    _decoders[idx] = updated;
    return updated;
  }

  @override
  Future<List<WifiBandConfig>> fetchWifiBands() async => List.of(_wifiBands);

  @override
  Future<void> setGlobalWifi(bool enabled) async {
    _info = _info.copyWith(wifiEnabled: enabled);
    _wifiBands = _wifiBands
        .map((b) => b.key.contains('guest') ? b : b.copyWith(enabled: enabled))
        .toList();
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Wi-Fi', 'Global Wi-Fi ${enabled ? "enabled" : "disabled"}');
  }

  @override
  Future<void> setGuestWifi(bool enabled, {int timerHours = 0}) async {
    _info = _info.copyWith(guestWifiEnabled: enabled);
    _wifiBands = _wifiBands
        .map((b) => b.key.contains('guest') ? b.copyWith(enabled: enabled) : b)
        .toList();
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Guest Wi-Fi',
        enabled ? 'Guest Wi-Fi enabled${timerHours > 0 ? " ($timerHours h)" : ""}' : 'Guest Wi-Fi disabled');
  }

  @override
  Future<void> setWifiScheduler(bool enabled) async {
    _info = _info.copyWith(wifiSchedulerEnabled: enabled);
  }

  @override
  Future<void> saveWifiBand(WifiBandConfig band) async {
    final idx = _wifiBands.indexWhere((b) => b.key == band.key);
    if (idx != -1) _wifiBands[idx] = band;
  }

  @override
  Future<void> setLedBrightness(int level) async {
    _info = _info.copyWith(orangeLedLevel: level);
  }

  @override
  Future<void> setShowWifiPasswordOnScreen(bool show) async {
    _info = _info.copyWith(showWifiPasswordOnScreen: show);
  }

  @override
  Future<void> rebootLivebox() async {
    _rebootHistory.insert(
      0,
      RebootEntry(
        bootDate: DateTime.now(),
        bootReason: 'GUI_Reboot',
        shutdownDate: DateTime.now().subtract(const Duration(seconds: 45)),
        shutdownReason: 'Initiated from Flutter Livebox Monitor',
      ),
    );
    _info = _info.copyWith(uptimeSeconds: 5);
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Reboot', 'Livebox reboot simulated');
  }

  @override
  Future<List<RebootEntry>> fetchRebootHistory() async => List.of(_rebootHistory);

  @override
  Future<List<DynDnsHost>> fetchDynDnsHosts() async => List.of(_dynDnsHosts);

  @override
  Future<void> addDynDnsHost(
      String service, String hostname, String username, String password) async {
    _dynDnsHosts.add(DynDnsHost(
      service: service,
      hostname: hostname,
      username: username,
      status: 'Updated',
      lastUpdate: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteDynDnsHost(String hostname) async {
    _dynDnsHosts.removeWhere((h) => h.hostname == hostname);
  }

  @override
  Future<List<StaticRoute>> fetchStaticRoutes() async => List.of(_staticRoutes);

  @override
  Future<void> addStaticRoute(String destination, String gateway) async {
    _staticRoutes.add(StaticRoute(
      id: 'rt_${DateTime.now().millisecondsSinceEpoch % 10000}',
      destination: destination,
      gateway: gateway,
      interfaceName: 'Bound (LAN)',
    ));
  }

  @override
  Future<void> deleteStaticRoute(String id) async {
    _staticRoutes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> triggerBackup() async {
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Backup', 'Cloud network configuration backup completed');
  }

  @override
  Future<void> triggerRestore() async {
    _pushDemoEvent('LIVEBOX', 'Livebox 7 W7', 'Restore', 'Cloud network configuration restore queued');
  }

  @override
  Future<SpeedTestResult> runSpeedTest() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return SpeedTestResult(
      timestamp: DateTime.now(),
      downloadMbps: 7420 + _rng.nextDouble() * 380,
      uploadMbps: 6180 + _rng.nextDouble() * 410,
      pingMs: 3.1 + _rng.nextDouble() * 1.4,
      server: 'Orange Paris XGS-PON (AutoDiag)',
    );
  }

  @override
  Future<String> executeRawApi(
      String service, String method, Map<String, dynamic> params) async {
    final simulated = switch ('$service:$method') {
      'DeviceInfo:get' => {
          'status': {
            'Manufacturer': _info.manufacturer,
            'ModelName': 'SagemcomFast5698_OFR',
            'ProductClass': _info.productClass,
            'SerialNumber': _info.serialNumber,
            'HardwareVersion': _info.hardwareVersion,
            'SoftwareVersion': _info.softwareVersion,
            'BaseMAC': _info.macAddress,
            'UpTime': _info.uptimeSeconds,
            'ExternalIPAddress': _info.wanIpv4,
          }
        },
      'NMC:getWANStatus' => {
          'status': true,
          'data': {
            'WanState': _info.wanStatus,
            'LinkType': _info.linkType,
            'LinkState': _info.linkState,
            'IPAddress': _info.wanIpv4,
            'RemoteGateway': _info.wanGateway,
            'DNSServers': _info.dnsServers.join(','),
          }
        },
      'Time:getTime' => {
          'status': true,
          'data': {'time': DateTime.now().toIso8601String()}
        },
      _ => {
          'status': true,
          'demo': true,
          'service': 'sysbus.$service',
          'method': method,
          'parameters': params,
          'message': 'Simulated sysbus reply in Demo Mode',
        },
    };
    return const JsonEncoder.withIndent('  ').convert(simulated);
  }
}
