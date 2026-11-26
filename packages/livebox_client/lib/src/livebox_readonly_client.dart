import 'livebox_session.dart';

/// Enforces strictly READ-ONLY access to the Orange Livebox sysbus API.
///
/// Any write/mutation method (e.g. `set*`, `add*`, `delete*`, `reboot`,
/// `reset`, `destroyDevice`, `sendWakeOnLan`) is blocked at runtime by an
/// explicit read-only allowlist.
class ReadOnlyLiveboxClient {
  final LiveboxSession _session;

  /// Explicit allowlist of strictly read-only sysbus methods.
  static const Set<String> allowedReadOnlyMethods = {
    'get',
    'getTime',
    'getWANStatus',
    'getLANIP',
    'getMIBs',
    'getNetDevStats',
    'getStationStats',
    'getFirstParameter',
    'buildTopology',
    'getReadingInterval',
    'getDevicesReadingInterval',
  };

  ReadOnlyLiveboxClient(this._session);

  bool get isAuthenticated => _session.isAuthenticated;
  List<String> get debugLogs => _session.debugLogs;
  String? get lastErrorDetail => _session.lastErrorDetail;
  String get baseUrl => _session.baseUrl;

  Future<int> signIn(String user, String password) =>
      _session.signIn(user, password);

  Future<void> close() => _session.close();

  /// Executes a strictly read-only sysbus call. Throws [UnsupportedError]
  /// if [method] is not in [allowedReadOnlyMethods].
  Future<dynamic> readOnlyCall(
    String service, {
    required String method,
    dynamic args,
    Duration timeout = LiveboxSession.defaultTimeout,
  }) {
    if (!allowedReadOnlyMethods.contains(method)) {
      throw UnsupportedError(
        'Read-only Livebox client blocked write/non-allowlisted method: $service:$method',
      );
    }
    return _session.callNoCheck(
      service,
      method: method,
      args: args,
      timeout: timeout,
    );
  }

  /// Executes a strictly read-only sysbus call returning full `{status, data}`.
  Future<Map<String, dynamic>> readOnlyCallRaw(
    String service, {
    required String method,
    dynamic args,
    Duration timeout = LiveboxSession.defaultTimeout,
  }) {
    if (!allowedReadOnlyMethods.contains(method)) {
      throw UnsupportedError(
        'Read-only Livebox client blocked write/non-allowlisted method: $service:$method',
      );
    }
    return _session.callRaw(
      service,
      method: method,
      args: args,
      timeout: timeout,
    );
  }

  /// Read-only event channel polling (`Devices.Device`, `HomeLan`).
  Future<Map<String, dynamic>?> pollEvents({
    List<String> events = const ['Devices.Device', 'HomeLan'],
    Duration timeout = const Duration(seconds: 3),
  }) =>
      _session.eventRequest(events, timeout: timeout);

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final res = await readOnlyCall('DeviceInfo', method: 'get');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getWanStatus() async {
    final res = await readOnlyCallRaw('NMC', method: 'getWANStatus');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getLanIp() async {
    final res = await readOnlyCallRaw('NMC', method: 'getLANIP');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getHomeLanInterfaces() async {
    final res = await readOnlyCall('HomeLan.Interface', method: 'get');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getPhysicalDevices() async {
    final res = await readOnlyCall(
      'Devices',
      method: 'get',
      args: {'expression': 'physical and !self and !voice'},
      timeout: const Duration(seconds: 12),
    );
    if (res is! List) return const [];
    return res.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getTopology() async {
    final res = await readOnlyCall(
      'TopologyDiagnostics',
      method: 'buildTopology',
      args: {'SendXmlFile': 'false'},
      timeout: const Duration(seconds: 20),
    );
    if (res is! List) return const [];
    return res.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getWifiStationStats(String intfKey) async {
    final res = await readOnlyCall(
      'NeMo.Intf.$intfKey',
      method: 'getStationStats',
    );
    if (res is! List) return const [];
    return res.whereType<Map<String, dynamic>>().toList();
  }

  /// Discovers all Wi-Fi VAP NeMo interface keys (e.g. `vap2g0priv`,
  /// `vap5g0priv`, `vap6g0priv`, `wl0`, `eth6`, guest VAPs) using read-only
  /// `NeMo.Intf.<lan|guest>:getMIBs`.
  Future<List<String>> getWifiVapInterfaceKeys() async {
    final keys = <String>{};
    for (final bridge in const ['lan', 'guest']) {
      try {
        final res = await readOnlyCall(
          'NeMo.Intf.$bridge',
          method: 'getMIBs',
          args: const {'mibs': 'wlanvap'},
        );
        if (res is Map) {
          final vaps = res['wlanvap'];
          if (vaps is Map) {
            for (final k in vaps.keys) {
              final s = k.toString().trim();
              if (s.isNotEmpty) keys.add(s);
            }
          }
        }
      } catch (_) {}
    }
    return keys.toList();
  }

  Future<Map<String, dynamic>> getInterfaceNetDevStats(String intfKey) async {
    final res = await readOnlyCall(
      'NeMo.Intf.$intfKey',
      method: 'getNetDevStats',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  static String detectCommercialModel(String productClass) {
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
}
