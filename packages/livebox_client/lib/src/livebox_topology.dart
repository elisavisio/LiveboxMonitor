/// Normalized topology tree node representing Livebox -> Repeaters -> Devices
/// with Ethernet vs Wi-Fi link metadata.
class LiveboxTopologyNode {
  final String id;
  final String name;
  final String role; // 'livebox' | 'repeater' | 'device'
  final String linkType; // 'root' | 'eth' | 'wifi24' | 'wifi5' | 'wifi6' | 'guest'
  final String interfaceLabel;
  final String ipAddress;
  final String deviceType;
  final bool active;
  final int? rssi;
  final int? linkSpeedMbps;
  final String? trust; // 'known' | 'unknown' (populated by server)
  final List<LiveboxTopologyNode> children;

  const LiveboxTopologyNode({
    required this.id,
    required this.name,
    required this.role,
    required this.linkType,
    required this.interfaceLabel,
    required this.ipAddress,
    required this.deviceType,
    required this.active,
    this.rssi,
    this.linkSpeedMbps,
    this.trust,
    this.children = const [],
  });

  LiveboxTopologyNode copyWith({
    String? trust,
    List<LiveboxTopologyNode>? children,
  }) =>
      LiveboxTopologyNode(
        id: id,
        name: name,
        role: role,
        linkType: linkType,
        interfaceLabel: interfaceLabel,
        ipAddress: ipAddress,
        deviceType: deviceType,
        active: active,
        rssi: rssi,
        linkSpeedMbps: linkSpeedMbps,
        trust: trust ?? this.trust,
        children: children ?? this.children,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'linkType': linkType,
        'interfaceLabel': interfaceLabel,
        'ipAddress': ipAddress,
        'deviceType': deviceType,
        'active': active,
        'rssi': rssi,
        'linkSpeedMbps': linkSpeedMbps,
        'trust': trust,
        'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Parses raw Livebox `TopologyDiagnostics:buildTopology` JSON into a clean
/// Livebox -> Repeaters -> Devices hierarchy preserving Ethernet & Wi-Fi links.
class LiveboxTopologyParser {
  LiveboxTopologyParser._();

  static bool isRepeaterNode(Map<String, dynamic> node) {
    final dt = (node['DeviceType']?.toString() ?? '').toLowerCase();
    final pc = (node['ProductClass']?.toString() ?? '').toLowerCase();
    final tags = (node['Tags']?.toString() ?? '').toLowerCase();
    return dt.contains('sah ap') ||
        dt.contains('repeteur') ||
        dt.contains('repeater') ||
        pc.contains('wifirep') ||
        pc.contains('wifi6rep') ||
        pc.contains('wifi7rep') ||
        tags.contains('ssw_ap');
  }

  static String classifyLinkType(Map<String, dynamic> node, {String parentIntf = ''}) {
    final intfType = (node['InterfaceType']?.toString() ?? '').toLowerCase();
    final intfName = (node['InterfaceName']?.toString() ?? parentIntf).toLowerCase();
    final band = (node['OperatingFrequencyBand']?.toString() ?? '').toLowerCase();
    final tags = (node['Tags']?.toString() ?? '').toLowerCase();

    final isWifi = intfType.contains('wi-fi') ||
        intfType.contains('wifi') ||
        intfName.contains('vap') ||
        intfName.contains('wl') ||
        tags.contains('wifi') ||
        node['SignalStrength'] != null;

    if (!isWifi) return 'eth';
    if (intfName.contains('guest')) return 'guest';
    if (band.contains('6') || intfName.contains('6g')) return 'wifi6';
    if (band.contains('5') || intfName.contains('5g')) return 'wifi5';
    return 'wifi24';
  }

  static String friendlyInterface(String raw, String linkType) {
    final low = raw.toLowerCase();
    if (low == 'eth0') return 'Eth 10G / 1';
    if (low.startsWith('eth')) return 'Ethernet ${raw.toUpperCase()}';
    if (linkType == 'guest') return 'Wi-Fi Invité';
    if (linkType == 'wifi6') return 'Wi-Fi 6 GHz';
    if (linkType == 'wifi5') return 'Wi-Fi 5 GHz';
    if (linkType == 'wifi24') return 'Wi-Fi 2.4 GHz';
    return raw.isNotEmpty ? raw : 'Ethernet';
  }

  /// Builds a normalized [LiveboxTopologyNode] tree from `buildTopology` output.
  static LiveboxTopologyNode parseFromTopology({
    required List<Map<String, dynamic>> rawTopology,
    required String liveboxModel,
    required String liveboxIp,
    required String liveboxMac,
  }) {
    final children = <LiveboxTopologyNode>[];

    void walk(Map<String, dynamic> node, List<LiveboxTopologyNode> target, String parentIntf) {
      final rawChildren = node['Children'];
      if (rawChildren is! List) return;

      for (final item in rawChildren) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final key = (m['Key']?.toString() ?? m['PhysAddress']?.toString() ?? '').toUpperCase();
        final tags = (m['Tags']?.toString() ?? '').toLowerCase();
        final hasMac = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(key);
        final nextIntf = (m['Name']?.toString() ?? m['Key']?.toString() ?? parentIntf);

        if (hasMac && !tags.contains('self') && !tags.contains('voice')) {
          final isRep = isRepeaterNode(m);
          final linkType = classifyLinkType(m, parentIntf: parentIntf);
          final subChildren = <LiveboxTopologyNode>[];
          walk(m, subChildren, nextIntf);

          final downKbps = (m['LastDataDownlinkRate'] as num?)?.toInt();
          target.add(LiveboxTopologyNode(
            id: key,
            name: (m['Name']?.toString().isNotEmpty == true) ? m['Name'].toString() : key,
            role: isRep ? 'repeater' : 'device',
            linkType: linkType,
            interfaceLabel: friendlyInterface(
              m['InterfaceName']?.toString() ?? parentIntf,
              linkType,
            ),
            ipAddress: m['IPAddress']?.toString() ?? '',
            deviceType: m['DeviceType']?.toString() ?? (isRep ? 'Wi-Fi Repeater' : 'Unknown'),
            active: m['Active'] == true,
            rssi: (m['SignalStrength'] as num?)?.toInt(),
            linkSpeedMbps: downKbps != null ? (downKbps ~/ 1000) : null,
            children: subChildren,
          ));
        } else {
          // Intermediate bridge / interface node (lan, guest, vap5g0priv, ETH0...)
          walk(m, target, nextIntf);
        }
      }
    }

    for (final root in rawTopology) {
      walk(root, children, '');
    }

    return LiveboxTopologyNode(
      id: liveboxMac.isNotEmpty ? liveboxMac.toUpperCase() : 'LIVEBOX',
      name: liveboxModel.isNotEmpty ? liveboxModel : 'Livebox',
      role: 'livebox',
      linkType: 'root',
      interfaceLabel: 'Gateway',
      ipAddress: liveboxIp,
      deviceType: 'Livebox',
      active: true,
      children: children,
    );
  }
}
