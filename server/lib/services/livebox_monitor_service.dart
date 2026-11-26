import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:livebox_client/livebox_client.dart';

import '../models/server_models.dart';
import '../storage/monitor_database.dart';
import '../storage/secret_vault.dart';
import 'email_notifier.dart';

class _ByteCounter {
  final int rxBytes;
  final int txBytes;
  final int tsMs;

  const _ByteCounter(this.rxBytes, this.txBytes, this.tsMs);
}

/// Core event-driven read-only Livebox monitoring service.
///
/// - Uses [ReadOnlyLiveboxClient] exclusively (no write/mutating API calls).
/// - Primarily driven by Livebox event channel (`Devices.Device`, `HomeLan`).
/// - Tracks per-device presence spans and Rx/Tx bandwidth samples in SQLite.
/// - Maintains Livebox -> Repeaters -> Eth/Wi-Fi -> Devices topology tree.
/// - Dispatches SMTP alerts whenever a new unknown device joins the network.
class LiveboxMonitorService {
  static const String appVersion = '1.1.0';

  static const List<String> demoSeedMacs = [
    'AA:BB:CC:10:00:01',
    'AA:BB:CC:10:00:02',
    'D4:5D:64:AA:11:01',
    '00:11:32:BB:22:02',
    'B8:27:EB:CC:33:03',
    '7C:2E:BD:DD:44:04',
    'F0:99:B6:EE:55:05',
    '3C:6A:A7:FF:66:06',
    '48:E1:E9:77:88:07',
    '9A:4C:12:88:99:08',
  ];

  final MonitorDatabase _liveDb;
  MonitorDatabase? _demoDb;
  final SecretVault vault;
  final EmailNotifier emailNotifier;
  final String? dashboardUrl;

  ReadOnlyLiveboxClient? _client;
  LiveboxCredentials _liveboxConfig = const LiveboxCredentials(
    url: 'http://livebox.home/',
    username: 'admin',
    demoMode: true,
  );
  SmtpConfig _smtpConfig = const SmtpConfig();

  bool _running = false;
  bool _connected = false;
  bool _demoMode = false;
  bool _initialSeedComplete = false;
  String _statusMessage = 'Initialisation...';
  String _liveboxModel = 'Livebox';
  String _liveboxIp = '';
  String _liveboxMac = 'LIVEBOX';
  String _wanState = 'unknown';
  String _wanIp = '';
  int _eventsReceived = 0;
  int _emailsSent = 0;
  int _emailsFailed = 0;
  String? _lastEmailError;

  LiveboxTopologyNode? _cachedTopology;
  final List<String> _wifiIntfKeys = <String>[];
  final Map<String, _ByteCounter> _prevCounters = <String, _ByteCounter>{};
  final Set<String> _notifiedMacs = <String>{};

  int _loopEpoch = 0;
  Timer? _statsTimer;
  Timer? _topologyTimer;
  Timer? _demoTimer;

  final StreamController<Map<String, dynamic>> _sseController =
      StreamController<Map<String, dynamic>>.broadcast();

  final Random _rng = Random();
  int _demoGuestCounter = 1;

  LiveboxMonitorService({
    required MonitorDatabase db,
    required this.vault,
    EmailNotifier? emailNotifier,
    this.dashboardUrl,
  })  : _liveDb = db,
        emailNotifier = emailNotifier ?? EmailNotifier();

  /// Returns an isolated in-memory database when in Demo Mode so real Livebox
  /// persistent storage is never polluted with simulated devices or history.
  MonitorDatabase get db =>
      _demoMode ? (_demoDb ??= MonitorDatabase.openInMemory()) : _liveDb;

  Stream<Map<String, dynamic>> get sseEvents => _sseController.stream;
  bool get isConnected => _connected;
  bool get isDemoMode => _demoMode;
  String get statusMessage => _statusMessage;
  LiveboxCredentials get liveboxConfig => _liveboxConfig;
  SmtpConfig get smtpConfig => _smtpConfig;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await vault.initialize();

    final savedLb = await vault.loadLiveboxCredentials();
    final savedSmtp = await vault.loadSmtpConfig();

    _smtpConfig = _applySmtpEnvDefaults(savedSmtp);
    if (savedLb != null) {
      _liveboxConfig = savedLb;
    } else {
      _liveboxConfig = _resolveInitialLiveboxConfigFromEnv();
    }

    await _startSessionForCurrentConfig();
  }

  LiveboxCredentials _resolveInitialLiveboxConfigFromEnv() {
    final envUrl = Platform.environment['LIVEBOX_URL']?.trim() ?? '';
    final envUser = Platform.environment['LIVEBOX_USER']?.trim() ?? 'admin';
    final envPass = Platform.environment['LIVEBOX_PASSWORD'] ?? '';
    final envDemo = Platform.environment['DEMO_MODE']?.toLowerCase();

    if (envDemo == 'true' || envDemo == '1') {
      return LiveboxCredentials(
        url: envUrl.isNotEmpty ? envUrl : 'http://livebox.home/',
        username: envUser,
        password: envPass,
        demoMode: true,
      );
    }

    if (envUrl.isNotEmpty && envPass.isNotEmpty) {
      return LiveboxCredentials(
        url: envUrl,
        username: envUser,
        password: envPass,
        demoMode: false,
      );
    }

    // Safe first-boot default: start in Demo Mode until user configures Livebox credentials
    return LiveboxCredentials(
      url: envUrl.isNotEmpty ? envUrl : 'http://livebox.home/',
      username: envUser,
      demoMode: true,
    );
  }

  SmtpConfig _applySmtpEnvDefaults(SmtpConfig saved) {
    if (saved.host.isNotEmpty) return saved;
    final host = Platform.environment['SMTP_HOST']?.trim() ?? '';
    if (host.isEmpty) return saved;
    return SmtpConfig(
      enabled: Platform.environment['SMTP_ENABLED']?.toLowerCase() != 'false',
      host: host,
      port: int.tryParse(Platform.environment['SMTP_PORT'] ?? '') ?? 587,
      useSsl: Platform.environment['SMTP_SSL']?.toLowerCase() == 'true',
      allowInsecure:
          Platform.environment['SMTP_ALLOW_INSECURE']?.toLowerCase() == 'true',
      username: Platform.environment['SMTP_USER'] ?? '',
      password: Platform.environment['SMTP_PASSWORD'] ?? '',
      fromAddress: Platform.environment['SMTP_FROM'] ?? '',
      toAddresses: Platform.environment['SMTP_TO'] ?? '',
    );
  }

  Future<void> _stopCurrentLoop() async {
    _loopEpoch++;
    _statsTimer?.cancel();
    _statsTimer = null;
    _topologyTimer?.cancel();
    _topologyTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;
    _connected = false;
    _initialSeedComplete = false;
    _cachedTopology = null;
    _liveboxModel = 'Livebox';
    _liveboxIp = '';
    _liveboxMac = 'LIVEBOX';
    _wanState = 'unknown';
    _wanIp = '';
    _eventsReceived = 0;
    _prevCounters.clear();
    _wifiIntfKeys.clear();
    _notifiedMacs.clear();
    if (_demoDb != null) {
      _demoDb!.close();
      _demoDb = null;
    }
    if (_client != null) {
      try {
        await _client!.close();
      } catch (_) {}
      _client = null;
    }
  }

  Future<void> _startSessionForCurrentConfig() async {
    await _stopCurrentLoop();
    final epoch = _loopEpoch;

    if (_liveboxConfig.demoMode) {
      _demoMode = true;
      _demoDb = MonitorDatabase.openInMemory();
      _connected = true;
      _statusMessage = 'Mode Démo actif (simulation temps réel)';
      _seedDemoEnvironment();
      _startDemoTicker(epoch);
      _broadcast('reload', _statusPayload());
      return;
    }

    _demoMode = false;
    // Scrub any demo records that may have been persisted by an earlier version
    final purged = _liveDb.purgeDemoArtifacts(
      demoSeedMacs,
      simulatedPrefix: 'DE:AD:BE:EF:',
    );
    if (purged > 0) {
      stdout.writeln(
        '[LiveboxMonitorServer] Purged $purged legacy demo device(s) from live SQLite DB',
      );
    }

    if (_liveboxConfig.password.isEmpty) {
      _connected = false;
      _statusMessage =
          'Mot de passe Livebox non configuré (configurez-le dans l\'onglet Configuration)';
      _broadcast('reload', _statusPayload());
      return;
    }

    _statusMessage = 'Connexion lecture seule à ${_liveboxConfig.url}...';
    _broadcast('reload', _statusPayload());

    unawaited(_runLiveEventLoop(epoch));
  }

  Future<void> _runLiveEventLoop(int epoch) async {
    while (_running && epoch == _loopEpoch && !_demoMode) {
      try {
        final session = LiveboxSession(
          _liveboxConfig.url,
          onLog: (msg) => stdout.writeln('[LiveboxReadOnly] $msg'),
        );
        final client = ReadOnlyLiveboxClient(session);
        _client = client;

        final authCode =
            await client.signIn(_liveboxConfig.username, _liveboxConfig.password);
        if (epoch != _loopEpoch || !_running) {
          await client.close();
          return;
        }

        if (authCode != 1) {
          _connected = false;
          _statusMessage =
              'Échec d\'authentification Livebox : ${client.lastErrorDetail ?? "vérifiez URL et mot de passe"}';
          _broadcast('status', _statusPayload());
          await client.close();
          _client = null;
          await Future<void>.delayed(const Duration(seconds: 15));
          continue;
        }

        _connected = true;
        _statusMessage = 'Connecté en lecture seule à ${_liveboxConfig.url}';
        _broadcast('status', _statusPayload());

        // 1. Initial read-only seed (info + devices + topology)
        await _seedFromLivebox(client);
        _initialSeedComplete = true;
        _broadcast('reload', _statusPayload());
        _broadcast('overview', getOverview());

        // 2. Periodic Wi-Fi station stats (5s) + topology refresh (60s)
        _statsTimer?.cancel();
        _statsTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => unawaited(_pollWifiStationStats(client, epoch)),
        );
        _topologyTimer?.cancel();
        int topoTick = 0;
        _topologyTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => unawaited(
            _refreshTopologyAndPrune(client, epoch, prune: (++topoTick % 4) == 0),
          ),
        );

        // 3. Main Livebox event loop (Devices.Device + HomeLan)
        int consecutiveFailures = 0;
        while (_running && epoch == _loopEpoch && !_demoMode) {
          final payload = await client.pollEvents(
            events: const ['Devices.Device', 'HomeLan'],
            timeout: const Duration(seconds: 3),
          );
          if (epoch != _loopEpoch || !_running) break;

          if (payload == null) {
            consecutiveFailures++;
            if (consecutiveFailures >= 8) {
              throw Exception('Perte du flux d\'événements Livebox');
            }
            await Future<void>.delayed(const Duration(seconds: 1));
            continue;
          }

          consecutiveFailures = 0;
          final rawEvents = payload['events'];
          if (rawEvents is List && rawEvents.isNotEmpty) {
            for (final ev in rawEvents) {
              if (ev is Map) {
                await _handleLiveboxEvent(Map<String, dynamic>.from(ev));
              }
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      } catch (e) {
        if (epoch != _loopEpoch || !_running) return;
        _connected = false;
        _statusMessage = 'Reconnexion en cours ($e)...';
        _broadcast('status', _statusPayload());
        _statsTimer?.cancel();
        _topologyTimer?.cancel();
        try {
          await _client?.close();
        } catch (_) {}
        _client = null;
        await Future<void>.delayed(const Duration(seconds: 8));
      }
    }
  }

  Future<void> _seedFromLivebox(ReadOnlyLiveboxClient client) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hadDevicesBefore = db.listDevices().isNotEmpty;

    try {
      final info = await client.getDeviceInfo();
      final pc = info['ProductClass']?.toString() ?? '';
      _liveboxModel = ReadOnlyLiveboxClient.detectCommercialModel(pc);
      final mac = info['BaseMAC']?.toString() ?? '';
      if (mac.isNotEmpty) _liveboxMac = mac.toUpperCase();
    } catch (_) {}

    try {
      final wan = await client.getWanStatus();
      _wanState = wan['WanState']?.toString() ?? 'up';
      _wanIp = wan['IPAddress']?.toString() ?? '';
    } catch (_) {}

    try {
      final lan = await client.getLanIp();
      final ip = lan['Address']?.toString() ?? '';
      if (ip.isNotEmpty) _liveboxIp = ip;
    } catch (_) {}

    try {
      final intfs = await client.getHomeLanInterfaces();
      _wifiIntfKeys.clear();
      for (final entry in intfs.entries) {
        final key = entry.key;
        final lower = key.toLowerCase();
        if (lower.startsWith('wl') ||
            lower.contains('vap') ||
            lower.contains('wifi')) {
          _wifiIntfKeys.add(key);
        }
      }
      if (_wifiIntfKeys.isEmpty) {
        _wifiIntfKeys.addAll(const ['wl0', 'eth6', 'wl1']);
      }
    } catch (_) {}

    // Topology first so we can map parent repeater MACs
    final parentMap = <String, String>{};
    try {
      final rawTopo = await client.getTopology();
      _cachedTopology = LiveboxTopologyParser.parseFromTopology(
        rawTopology: rawTopo,
        liveboxModel: _liveboxModel,
        liveboxIp: _liveboxIp,
        liveboxMac: _liveboxMac,
      );
      _extractParentMap(_cachedTopology!, _cachedTopology!.id, parentMap);
    } catch (_) {}

    try {
      final rawDevices = await client.getPhysicalDevices();
      for (final raw in rawDevices) {
        final parsed = _parseRawDevice(raw, nowMs: nowMs, parentMap: parentMap);
        if (parsed == null) continue;
        final res = db.upsertDevice(parsed, nowMs: nowMs);
        // Only send email on seed if DB already existed (not very first cold scan)
        if (res.isNew && hadDevicesBefore) {
          unawaited(_handleNewDeviceDiscovered(res.device, raw));
        }
      }
    } catch (_) {}

    if (_cachedTopology == null) {
      _cachedTopology = _buildFallbackTopologyFromDb();
    }
  }

  void _extractParentMap(
    LiveboxTopologyNode node,
    String parentId,
    Map<String, String> out,
  ) {
    for (final child in node.children) {
      out[child.id.toUpperCase()] = parentId;
      _extractParentMap(
        child,
        child.role == 'repeater' ? child.id.toUpperCase() : parentId,
        out,
      );
    }
  }

  ServerDevice? _parseRawDevice(
    Map<String, dynamic> raw, {
    required int nowMs,
    Map<String, String> parentMap = const {},
  }) {
    final key = (raw['Key']?.toString() ?? raw['PhysAddress']?.toString() ?? '')
        .toUpperCase();
    if (key.isEmpty || !RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(key)) {
      return null;
    }

    final linkType = LiveboxTopologyParser.classifyLinkType(raw);
    final rawIntf = raw['InterfaceName']?.toString() ?? '';
    final friendlyIntf = LiveboxTopologyParser.friendlyInterface(rawIntf, linkType);
    final downKbps = (raw['LastDataDownlinkRate'] as num?)?.toInt();

    String ipv6 = '';
    final v6List = raw['IPv6Address'];
    if (v6List is List && v6List.isNotEmpty) {
      final first = v6List.first;
      if (first is Map && first['Address'] != null) {
        ipv6 = first['Address'].toString();
      }
    }

    return ServerDevice(
      mac: key,
      name: (raw['Name']?.toString().trim().isNotEmpty == true)
          ? raw['Name'].toString().trim()
          : key,
      vendor: raw['VendorClassID']?.toString() ??
          raw['Manufacturer']?.toString() ??
          '',
      deviceType: raw['DeviceType']?.toString() ?? 'Unknown',
      ipAddress: raw['IPAddress']?.toString() ?? '',
      ipv6Address: ipv6,
      active: raw['Active'] == true,
      linkType: linkType,
      interfaceName: friendlyIntf,
      parentNodeId: parentMap[key] ?? _liveboxMac,
      rssi: (raw['SignalStrength'] as num?)?.toInt(),
      linkSpeedMbps: downKbps != null ? (downKbps ~/ 1000) : null,
      trust: DeviceTrust.unknown,
      firstSeenMs: nowMs,
      lastSeenMs: nowMs,
      lastChangedMs: nowMs,
    );
  }

  Future<void> _handleLiveboxEvent(Map<String, dynamic> event) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final handler = event['handler']?.toString() ?? '';
    final obj = event['object'];
    if (obj is! Map) return;
    final object = Map<String, dynamic>.from(obj);
    final reason = object['reason']?.toString() ?? 'event';
    final attrs = object['attributes'] is Map
        ? Map<String, dynamic>.from(object['attributes'] as Map)
        : <String, dynamic>{};

    _eventsReceived++;

    // 1. Livebox Statistics events (per-device byte counters)
    if (reason == 'Statistics' || handler.startsWith('HomeLan')) {
      for (final entry in attrs.entries) {
        final key = entry.key.toUpperCase();
        if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(key)) continue;
        if (entry.value is! Map) continue;
        final stat = Map<String, dynamic>.from(entry.value as Map);
        final rx = (stat['RxBytes'] as num?)?.toInt();
        final tx = (stat['TxBytes'] as num?)?.toInt();
        if (rx != null && tx != null) {
          _recordByteCounter(key, rxBytes: rx, txBytes: tx, tsMs: nowMs);
        }
      }
      return;
    }

    // 2. Device lifecycle / state events (Devices.Device.<MAC>)
    String mac = '';
    if (handler.startsWith('Devices.Device.')) {
      mac = handler.substring('Devices.Device.'.length).split('.').first.toUpperCase();
    } else if (attrs['Key'] != null) {
      mac = attrs['Key'].toString().toUpperCase();
    } else if (attrs['PhysAddress'] != null) {
      mac = attrs['PhysAddress'].toString().toUpperCase();
    }
    if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac)) return;

    final existing = db.getDevice(mac);
    final incomingActive = attrs.containsKey('Active')
        ? attrs['Active'] == true
        : (reason.contains('deleted') ? false : (existing?.active ?? true));
    final incomingName = attrs['Name']?.toString().trim();
    final incomingIp = attrs['IPAddress']?.toString();
    final incomingRssi = (attrs['SignalStrength'] as num?)?.toInt();
    final linkType = attrs.containsKey('InterfaceType') ||
            attrs.containsKey('InterfaceName') ||
            attrs.containsKey('SignalStrength')
        ? LiveboxTopologyParser.classifyLinkType(attrs)
        : (existing?.linkType ?? 'eth');
    final intfLabel = attrs.containsKey('InterfaceName')
        ? LiveboxTopologyParser.friendlyInterface(
            attrs['InterfaceName'].toString(),
            linkType,
          )
        : (existing?.interfaceName ?? '');

    final candidate = ServerDevice(
      mac: mac,
      name: (incomingName != null && incomingName.isNotEmpty)
          ? incomingName
          : (existing?.name ?? mac),
      vendor: attrs['VendorClassID']?.toString() ?? existing?.vendor ?? '',
      deviceType: attrs['DeviceType']?.toString() ?? existing?.deviceType ?? 'Unknown',
      ipAddress: (incomingIp != null && incomingIp.isNotEmpty)
          ? incomingIp
          : (existing?.ipAddress ?? ''),
      ipv6Address: existing?.ipv6Address ?? '',
      active: incomingActive,
      linkType: linkType,
      interfaceName: intfLabel,
      parentNodeId: existing?.parentNodeId ?? _liveboxMac,
      rssi: incomingRssi ?? existing?.rssi,
      linkSpeedMbps: existing?.linkSpeedMbps,
      rxBytes: existing?.rxBytes ?? 0,
      txBytes: existing?.txBytes ?? 0,
      rxBytesPerSec: existing?.rxBytesPerSec ?? 0,
      txBytesPerSec: existing?.txBytesPerSec ?? 0,
      trust: existing?.trust ?? DeviceTrust.unknown,
      firstSeenMs: existing?.firstSeenMs ?? nowMs,
      lastSeenMs: nowMs,
      lastChangedMs: nowMs,
    );

    final upsert = db.upsertDevice(candidate, nowMs: nowMs);

    String summary = reason;
    if (upsert.isNew) {
      summary = 'Nouvel équipement détecté (${upsert.device.ipAddress.isNotEmpty ? upsert.device.ipAddress : "sans IP"})';
    } else if (upsert.presenceChanged) {
      summary = upsert.device.active ? 'Connecté au réseau' : 'Déconnecté du réseau';
    } else if (incomingIp != null && incomingIp != existing?.ipAddress) {
      summary = 'Adresse IP attribuée : $incomingIp';
    } else if (incomingName != null && incomingName != existing?.name) {
      summary = 'Renommé en $incomingName';
    }

    final logged = db.insertEvent(
      deviceMac: mac,
      deviceName: upsert.device.name,
      reason: upsert.isNew ? 'new_device' : reason,
      summary: summary,
      rawJson: jsonEncode(event),
      tsMs: nowMs,
    );

    _broadcast('event', logged.toJson());
    _broadcast('device_update', upsert.device.toJson());

    if (upsert.isNew && _initialSeedComplete) {
      await _handleNewDeviceDiscovered(upsert.device, event);
    }
  }

  Future<void> _handleNewDeviceDiscovered(
    ServerDevice device,
    Map<String, dynamic> rawContext,
  ) async {
    if (_notifiedMacs.contains(device.mac)) return;
    _notifiedMacs.add(device.mac);

    _broadcast('new_device', {
      'device': device.toJson(),
      'message': 'Nouvel équipement inconnu détecté : ${device.name} (${device.mac})',
    });

    if (_smtpConfig.enabled && _smtpConfig.host.trim().isNotEmpty) {
      try {
        final sent = await emailNotifier.notifyNewDevice(
          config: _smtpConfig,
          device: device,
          dashboardUrl: dashboardUrl,
        );
        if (sent) {
          _emailsSent++;
          _lastEmailError = null;
          final mailEv = db.insertEvent(
            deviceMac: device.mac,
            deviceName: device.name,
            reason: 'email_sent',
            summary: 'Alerte email envoyée à ${_smtpConfig.toAddresses}',
            rawJson: jsonEncode({'to': _smtpConfig.recipientList, 'mac': device.mac}),
          );
          _broadcast('event', mailEv.toJson());
        }
      } catch (e) {
        _emailsFailed++;
        _lastEmailError = e.toString();
        final errEv = db.insertEvent(
          deviceMac: device.mac,
          deviceName: device.name,
          reason: 'email_error',
          summary: 'Échec envoi email : $e',
          rawJson: jsonEncode({'error': e.toString(), 'mac': device.mac}),
        );
        _broadcast('event', errEv.toJson());
      }
    }
  }

  Future<void> _pollWifiStationStats(
    ReadOnlyLiveboxClient client,
    int epoch,
  ) async {
    if (!_running || epoch != _loopEpoch || !_connected || _demoMode) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final intf in List<String>.from(_wifiIntfKeys)) {
      if (epoch != _loopEpoch) return;
      try {
        final stations = await client.getWifiStationStats(intf);
        for (final st in stations) {
          final mac = (st['MACAddress']?.toString() ??
                  st['PhysAddress']?.toString() ??
                  st['Key']?.toString() ??
                  '')
              .toUpperCase();
          if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac)) continue;
          // Router TxBytes = device Download (Rx), Router RxBytes = device Upload (Tx)
          final routerTx = (st['TxBytes'] as num?)?.toInt();
          final routerRx = (st['RxBytes'] as num?)?.toInt();
          if (routerTx != null && routerRx != null) {
            _recordByteCounter(
              mac,
              rxBytes: routerTx,
              txBytes: routerRx,
              tsMs: nowMs,
            );
          }
        }
      } catch (_) {}
    }
  }

  void _recordByteCounter(
    String mac, {
    required int rxBytes,
    required int txBytes,
    required int tsMs,
  }) {
    final prev = _prevCounters[mac];
    _prevCounters[mac] = _ByteCounter(rxBytes, txBytes, tsMs);
    if (prev == null) return;

    final dtSec = (tsMs - prev.tsMs) / 1000.0;
    if (dtSec <= 0.2) return;

    int delta(int curr, int old) {
      if (curr >= old) return curr - old;
      // 32-bit counter wrap handling
      if (old <= 0xFFFFFFFF && curr <= 0xFFFFFFFF) {
        return (0x100000000 - old) + curr;
      }
      return 0;
    }

    final dRx = delta(rxBytes, prev.rxBytes);
    final dTx = delta(txBytes, prev.txBytes);
    final rxBps = dRx / dtSec;
    final txBps = dTx / dtSec;

    if (db.getDevice(mac) != null) {
      db.updateDeviceBandwidth(
        mac: mac,
        rxBytes: rxBytes,
        txBytes: txBytes,
        rxBytesPerSec: rxBps,
        txBytesPerSec: txBps,
        tsMs: tsMs,
      );
      _broadcast('bandwidth', {
        'mac': mac,
        'rxBytesPerSec': rxBps,
        'txBytesPerSec': txBps,
        'timestampMs': tsMs,
      });
    }
  }

  Future<void> _refreshTopologyAndPrune(
    ReadOnlyLiveboxClient client,
    int epoch, {
    bool prune = true,
  }) async {
    if (!_running || epoch != _loopEpoch || !_connected || _demoMode) return;
    try {
      final rawTopo = await client.getTopology();
      if (rawTopo.isNotEmpty) {
        _cachedTopology = LiveboxTopologyParser.parseFromTopology(
          rawTopology: rawTopo,
          liveboxModel: _liveboxModel,
          liveboxIp: _liveboxIp,
          liveboxMac: _liveboxMac,
        );
        _broadcast('topology', getTopology());
      }
    } catch (_) {}
    if (prune) {
      db.pruneOldHistory(retentionDays: 7);
    }
  }

  // ---------------------------------------------------------------------------
  // DEMO MODE (rich simulation with Livebox W7 + 2 Repeaters + 24h graphs)
  // ---------------------------------------------------------------------------

  void _seedDemoEnvironment() {
    _liveboxModel = 'Livebox 7 (W7) — Démo';
    _liveboxIp = '192.168.1.1';
    _liveboxMac = 'AA:BB:CC:00:00:01';
    _wanState = 'up';
    _wanIp = '86.245.142.19';

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = db.listDevices();

    final demoSeed = <ServerDevice>[
      ServerDevice(
        mac: 'AA:BB:CC:10:00:01',
        name: 'Répéteur Wi-Fi 6 Salon',
        vendor: 'Sagemcom',
        deviceType: 'Wi-Fi Repeater',
        ipAddress: '192.168.1.10',
        active: true,
        linkType: 'eth',
        interfaceName: 'Eth 10G / 1',
        parentNodeId: _liveboxMac,
        linkSpeedMbps: 2500,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 14,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 86400000 * 5,
      ),
      ServerDevice(
        mac: 'AA:BB:CC:10:00:02',
        name: 'Répéteur Wi-Fi 6 Étage',
        vendor: 'Sagemcom',
        deviceType: 'Wi-Fi Repeater',
        ipAddress: '192.168.1.11',
        active: true,
        linkType: 'wifi5',
        interfaceName: 'Wi-Fi 5 GHz',
        parentNodeId: _liveboxMac,
        rssi: -54,
        linkSpeedMbps: 1733,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 14,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 86400000 * 3,
      ),
      ServerDevice(
        mac: 'D4:5D:64:AA:11:01',
        name: 'MacBook-Pro-Studio',
        vendor: 'Apple',
        deviceType: 'Computer',
        ipAddress: '192.168.1.24',
        active: true,
        linkType: 'wifi6',
        interfaceName: 'Wi-Fi 6 GHz',
        parentNodeId: _liveboxMac,
        rssi: -46,
        linkSpeedMbps: 2402,
        rxBytesPerSec: 4250000,
        txBytesPerSec: 680000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 30,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 3600000 * 4,
      ),
      ServerDevice(
        mac: '00:11:32:BB:22:02',
        name: 'NAS-Synology-DS923',
        vendor: 'Synology',
        deviceType: 'NAS',
        ipAddress: '192.168.1.50',
        active: true,
        linkType: 'eth',
        interfaceName: 'Ethernet ETH2',
        parentNodeId: _liveboxMac,
        linkSpeedMbps: 1000,
        rxBytesPerSec: 1850000,
        txBytesPerSec: 3420000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 60,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 86400000 * 10,
      ),
      ServerDevice(
        mac: 'B8:27:EB:CC:33:03',
        name: 'HomeAssistant-Pi5',
        vendor: 'Raspberry Pi',
        deviceType: 'IoT',
        ipAddress: '192.168.1.52',
        active: true,
        linkType: 'eth',
        interfaceName: 'Ethernet ETH3',
        parentNodeId: _liveboxMac,
        linkSpeedMbps: 1000,
        rxBytesPerSec: 85000,
        txBytesPerSec: 42000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 45,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 86400000 * 12,
      ),
      ServerDevice(
        mac: '7C:2E:BD:DD:44:04',
        name: 'Apple-TV-4K-Salon',
        vendor: 'Apple',
        deviceType: 'Set-top Box',
        ipAddress: '192.168.1.31',
        active: true,
        linkType: 'eth',
        interfaceName: 'Ethernet Répéteur',
        parentNodeId: 'AA:BB:CC:10:00:01',
        linkSpeedMbps: 1000,
        rxBytesPerSec: 3150000,
        txBytesPerSec: 95000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 20,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 3600000 * 2,
      ),
      ServerDevice(
        mac: 'F0:99:B6:EE:55:05',
        name: 'iPhone-16-Pro',
        vendor: 'Apple',
        deviceType: 'Phone',
        ipAddress: '192.168.1.38',
        active: true,
        linkType: 'wifi5',
        interfaceName: 'Wi-Fi 5 GHz',
        parentNodeId: 'AA:BB:CC:10:00:01',
        rssi: -52,
        linkSpeedMbps: 1200,
        rxBytesPerSec: 540000,
        txBytesPerSec: 120000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 18,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 1800000,
      ),
      ServerDevice(
        mac: '3C:6A:A7:FF:66:06',
        name: 'iPad-Pro-Bureau',
        vendor: 'Apple',
        deviceType: 'Tablet',
        ipAddress: '192.168.1.41',
        active: true,
        linkType: 'wifi5',
        interfaceName: 'Wi-Fi 5 GHz',
        parentNodeId: 'AA:BB:CC:10:00:02',
        rssi: -61,
        linkSpeedMbps: 866,
        rxBytesPerSec: 920000,
        txBytesPerSec: 165000,
        trust: DeviceTrust.known,
        firstSeenMs: nowMs - 86400000 * 12,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 7200000,
      ),
      ServerDevice(
        mac: '48:E1:E9:77:88:07',
        name: 'ESP32-Capteur-Jardin',
        vendor: 'Espressif',
        deviceType: 'IoT',
        ipAddress: '192.168.1.77',
        active: true,
        linkType: 'wifi24',
        interfaceName: 'Wi-Fi 2.4 GHz',
        parentNodeId: 'AA:BB:CC:10:00:02',
        rssi: -71,
        linkSpeedMbps: 72,
        rxBytesPerSec: 4500,
        txBytesPerSec: 8200,
        trust: DeviceTrust.unknown,
        firstSeenMs: nowMs - 3600000 * 5,
        lastSeenMs: nowMs,
        lastChangedMs: nowMs - 3600000 * 5,
      ),
      ServerDevice(
        mac: '9A:4C:12:88:99:08',
        name: 'Galaxy-Visiteur',
        vendor: 'Samsung',
        deviceType: 'Phone',
        ipAddress: '192.168.1.89',
        active: false,
        linkType: 'guest',
        interfaceName: 'Wi-Fi Invité',
        parentNodeId: _liveboxMac,
        rssi: -66,
        linkSpeedMbps: 433,
        trust: DeviceTrust.unknown,
        firstSeenMs: nowMs - 3600000 * 11,
        lastSeenMs: nowMs - 3600000 * 2,
        lastChangedMs: nowMs - 3600000 * 2,
      ),
    ];

    if (existing.isEmpty) {
      for (final d in demoSeed) {
        db.upsertDevice(d, nowMs: nowMs);
        _seedDemoHistoryForDevice(d, nowMs);
      }
      db.insertEvent(
        deviceMac: '48:E1:E9:77:88:07',
        deviceName: 'ESP32-Capteur-Jardin',
        reason: 'new_device',
        summary: 'Nouvel équipement détecté (192.168.1.77) — marqué Inconnu',
        rawJson: jsonEncode({'demo': true, 'mac': '48:E1:E9:77:88:07'}),
        tsMs: nowMs - 3600000 * 5,
      );
      db.insertEvent(
        deviceMac: 'D4:5D:64:AA:11:01',
        deviceName: 'MacBook-Pro-Studio',
        reason: 'changed',
        summary: 'Connecté en Wi-Fi 6 GHz (-46 dBm)',
        rawJson: jsonEncode({'demo': true, 'mac': 'D4:5D:64:AA:11:01'}),
        tsMs: nowMs - 3600000 * 2,
      );
    }

    _cachedTopology = _buildFallbackTopologyFromDb();
    _initialSeedComplete = true;
  }

  void _seedDemoHistoryForDevice(ServerDevice d, int nowMs) {
    // 24h presence transitions
    final dayAgo = nowMs - 24 * 3600 * 1000;
    if (d.deviceType == 'NAS' ||
        d.deviceType == 'IoT' ||
        d.deviceType == 'Wi-Fi Repeater') {
      db.recordPresence(d.mac, true, dayAgo);
    } else if (!d.active) {
      db.recordPresence(d.mac, false, dayAgo);
      db.recordPresence(d.mac, true, nowMs - 11 * 3600 * 1000);
      db.recordPresence(d.mac, false, nowMs - 2 * 3600 * 1000);
    } else {
      db.recordPresence(d.mac, false, dayAgo);
      db.recordPresence(d.mac, true, nowMs - 19 * 3600 * 1000);
      db.recordPresence(d.mac, false, nowMs - 13 * 3600 * 1000);
      db.recordPresence(d.mac, true, nowMs - 8 * 3600 * 1000);
    }

    // 48 bandwidth samples over last 24h (every 30 min)
    int cumRx = 10000000;
    int cumTx = 2500000;
    final baseRx = d.rxBytesPerSec > 0 ? d.rxBytesPerSec : 50000.0;
    final baseTx = d.txBytesPerSec > 0 ? d.txBytesPerSec : 15000.0;

    for (int i = 48; i >= 1; i--) {
      final ts = nowMs - i * 1800 * 1000;
      final wave = 0.55 + 0.45 * sin(i * 0.45) + _rng.nextDouble() * 0.45;
      final rx = d.active ? baseRx * wave : (i > 4 && i < 22 ? baseRx * wave : 0.0);
      final tx = d.active ? baseTx * wave : (i > 4 && i < 22 ? baseTx * wave : 0.0);
      cumRx += (rx * 1800).round();
      cumTx += (tx * 1800).round();
      db.updateDeviceBandwidth(
        mac: d.mac,
        rxBytes: cumRx,
        txBytes: cumTx,
        rxBytesPerSec: rx,
        txBytesPerSec: tx,
        tsMs: ts,
      );
    }
  }

  void _startDemoTicker(int epoch) {
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_running || epoch != _loopEpoch || !_demoMode) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final devices = db.listDevices().where((d) => d.active).toList();
      for (final d in devices) {
        final factor = 0.72 + _rng.nextDouble() * 0.62;
        final baseRx = d.rxBytesPerSec > 1000 ? d.rxBytesPerSec : 120000.0;
        final baseTx = d.txBytesPerSec > 500 ? d.txBytesPerSec : 35000.0;
        final rx = (baseRx * factor).clamp(1500.0, 28000000.0);
        final tx = (baseTx * factor).clamp(800.0, 12000000.0);
        db.updateDeviceBandwidth(
          mac: d.mac,
          rxBytes: d.rxBytes + (rx * 3).round(),
          txBytes: d.txBytes + (tx * 3).round(),
          rxBytesPerSec: rx,
          txBytesPerSec: tx,
          tsMs: nowMs,
        );
      }
      _eventsReceived++;
      _broadcast('tick', {'timestampMs': nowMs, 'eventsReceived': _eventsReceived});
    });
  }

  /// Simulates the arrival of a brand-new unknown device (handy to test live
  /// SSE alerts, presence tracking, and SMTP email notifications).
  Future<ServerDevice> simulateNewDevice() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final n = _demoGuestCounter++;
    final hex = (0xA0 + n).toRadixString(16).toUpperCase().padLeft(2, '0');
    final mac = 'DE:AD:BE:EF:${(nowMs % 90 + 10)}:$hex';
    final ip = '192.168.1.${150 + (n % 90)}';
    final isWifi = n.isOdd;

    final incoming = ServerDevice(
      mac: mac,
      name: 'Appareil-Inconnu-$n',
      vendor: isWifi ? 'Unknown Mobile' : 'Generic Ethernet',
      deviceType: isWifi ? 'Phone' : 'Computer',
      ipAddress: ip,
      active: true,
      linkType: isWifi ? 'wifi5' : 'eth',
      interfaceName: isWifi ? 'Wi-Fi 5 GHz' : 'Ethernet ETH4',
      parentNodeId: isWifi ? 'AA:BB:CC:10:00:01' : _liveboxMac,
      rssi: isWifi ? -58 : null,
      linkSpeedMbps: isWifi ? 866 : 1000,
      rxBytesPerSec: 180000,
      txBytesPerSec: 45000,
      trust: DeviceTrust.unknown,
      firstSeenMs: nowMs,
      lastSeenMs: nowMs,
      lastChangedMs: nowMs,
    );

    final res = db.upsertDevice(incoming, nowMs: nowMs);
    db.updateDeviceBandwidth(
      mac: res.device.mac,
      rxBytes: 540000,
      txBytes: 135000,
      rxBytesPerSec: 180000,
      txBytesPerSec: 45000,
      tsMs: nowMs,
    );

    final ev = db.insertEvent(
      deviceMac: res.device.mac,
      deviceName: res.device.name,
      reason: 'new_device',
      summary: 'Nouvel équipement inconnu détecté ($ip)',
      rawJson: jsonEncode({'simulated': true, 'device': res.device.toJson()}),
      tsMs: nowMs,
    );

    _cachedTopology = _buildFallbackTopologyFromDb();
    _broadcast('event', ev.toJson());
    _broadcast('device_update', res.device.toJson());
    _broadcast('topology', getTopology());

    await _handleNewDeviceDiscovered(res.device, {'simulated': true});
    return res.device;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC QUERY & CONFIG METHODS FOR HTTP ROUTES
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _statusPayload() => {
        'version': appVersion,
        'connected': _connected,
        'demoMode': _demoMode,
        'readOnlyEnforced': true,
        'statusMessage': _statusMessage,
        'liveboxModel': _liveboxModel,
        'liveboxIp': _liveboxIp,
        'wanState': _wanState,
        'wanIp': _wanIp,
        'eventsReceived': _eventsReceived,
        'emailsSent': _emailsSent,
        'emailsFailed': _emailsFailed,
        'lastEmailError': _lastEmailError,
        'vaultKeySource': vault.keySource,
      };

  Map<String, dynamic> getOverview() {
    final devices = db.listDevices();
    final activeWithIp = devices.where((d) => d.isActiveWithIp).toList();
    final knownCount = devices.where((d) => d.trust == DeviceTrust.known).length;
    final unknownCount =
        devices.where((d) => d.trust == DeviceTrust.unknown).length;
    final activeUnknownCount =
        activeWithIp.where((d) => d.trust == DeviceTrust.unknown).length;
    final totalRxBps =
        activeWithIp.fold<double>(0, (sum, d) => sum + d.rxBytesPerSec);
    final totalTxBps =
        activeWithIp.fold<double>(0, (sum, d) => sum + d.txBytesPerSec);

    return {
      ..._statusPayload(),
      'stats': {
        'totalDevices': devices.length,
        'activeWithIp': activeWithIp.length,
        'knownDevices': knownCount,
        'unknownDevices': unknownCount,
        'activeUnknownDevices': activeUnknownCount,
        'wifiActive': activeWithIp.where((d) => d.isWifi).length,
        'ethActive': activeWithIp.where((d) => !d.isWifi).length,
        'totalRxBytesPerSec': totalRxBps,
        'totalTxBytesPerSec': totalTxBps,
      },
    };
  }

  List<Map<String, dynamic>> listDevicesJson() =>
      db.listDevices().map((d) => d.toJson()).toList();

  Map<String, dynamic>? getDeviceDetail(String mac, {int hours = 24}) {
    final device = db.getDevice(mac);
    if (device == null) return null;
    final sinceMs = DateTime.now()
        .subtract(Duration(hours: hours.clamp(1, 168)))
        .millisecondsSinceEpoch;
    final presence = db.getPresenceTimeline(device.mac, sinceMs: sinceMs);
    final bandwidth = db.getBandwidthHistory(device.mac, sinceMs: sinceMs);
    return {
      'device': device.toJson(),
      'hours': hours,
      'uptimePercent': presence.uptimePercent,
      'presence': presence.spans.map((s) => s.toJson()).toList(),
      'bandwidth': bandwidth.map((b) => b.toJson()).toList(),
    };
  }

  ServerDevice? tagDevice(String mac, DeviceTrust trust, {String? note}) {
    final updated = db.setDeviceTrust(mac, trust, note: note);
    if (updated != null) {
      final ev = db.insertEvent(
        deviceMac: updated.mac,
        deviceName: updated.name,
        reason: 'trust_changed',
        summary: trust == DeviceTrust.known
            ? 'Marqué comme équipement CONNU'
            : 'Marqué comme équipement INCONNU',
        rawJson: jsonEncode({'mac': updated.mac, 'trust': trust.name, 'note': updated.note}),
      );
      _broadcast('device_update', updated.toJson());
      _broadcast('event', ev.toJson());
    }
    return updated;
  }

  Map<String, dynamic> getTopology() {
    final devicesByMac = {
      for (final d in db.listDevices()) d.mac.toUpperCase(): d,
    };

    final root = (_cachedTopology != null && !_demoMode)
        ? _enrichTopologyNode(_cachedTopology!, devicesByMac)
        : _buildFallbackTopologyFromDb();

    return _enrichTopologyToMap(root, devicesByMac);
  }

  LiveboxTopologyNode _enrichTopologyNode(
    LiveboxTopologyNode node,
    Map<String, ServerDevice> devicesByMac,
  ) {
    final dbDev = devicesByMac[node.id.toUpperCase()];
    return node.copyWith(
      trust: dbDev?.trust.name,
      children: node.children
          .map((c) => _enrichTopologyNode(c, devicesByMac))
          .toList(),
    );
  }

  Map<String, dynamic> _enrichTopologyToMap(
    LiveboxTopologyNode node,
    Map<String, ServerDevice> devicesByMac,
  ) {
    final dbDev = devicesByMac[node.id.toUpperCase()];
    final json = node.toJson();
    if (dbDev != null) {
      if (dbDev.ipAddress.isNotEmpty) json['ipAddress'] = dbDev.ipAddress;
      if (dbDev.name.isNotEmpty) json['name'] = dbDev.name;
      json['active'] = dbDev.active;
      if (dbDev.rssi != null) json['rssi'] = dbDev.rssi;
    }
    json['trust'] = dbDev?.trust.name ?? node.trust;
    json['rxBytesPerSec'] = dbDev?.rxBytesPerSec ?? 0;
    json['txBytesPerSec'] = dbDev?.txBytesPerSec ?? 0;
    json['vendor'] = dbDev?.vendor ?? '';
    json['children'] = node.children
        .map((c) => _enrichTopologyToMap(c, devicesByMac))
        .toList();
    return json;
  }

  LiveboxTopologyNode _buildFallbackTopologyFromDb() {
    final all = db.listDevices();
    final repeaters = all
        .where((d) =>
            d.deviceType.toLowerCase().contains('repeater') ||
            d.deviceType.toLowerCase().contains('répéteur') ||
            d.deviceType.toLowerCase().contains('sah ap'))
        .toList();
    final repeaterIds = repeaters.map((r) => r.mac.toUpperCase()).toSet();

    LiveboxTopologyNode toNode(ServerDevice d, List<LiveboxTopologyNode> kids) =>
        LiveboxTopologyNode(
          id: d.mac,
          name: d.name,
          role: repeaterIds.contains(d.mac.toUpperCase()) ? 'repeater' : 'device',
          linkType: d.linkType,
          interfaceLabel: d.interfaceName,
          ipAddress: d.ipAddress,
          deviceType: d.deviceType,
          active: d.active,
          rssi: d.rssi,
          linkSpeedMbps: d.linkSpeedMbps,
          trust: d.trust.name,
          children: kids,
        );

    final childrenByParent = <String, List<ServerDevice>>{};
    for (final d in all) {
      if (repeaterIds.contains(d.mac.toUpperCase())) continue;
      final pid = repeaterIds.contains(d.parentNodeId.toUpperCase())
          ? d.parentNodeId.toUpperCase()
          : _liveboxMac;
      childrenByParent.putIfAbsent(pid, () => <ServerDevice>[]).add(d);
    }

    final rootChildren = <LiveboxTopologyNode>[];
    for (final r in repeaters) {
      final repKids =
          (childrenByParent[r.mac.toUpperCase()] ?? const <ServerDevice>[])
              .map((d) => toNode(d, const []))
              .toList();
      rootChildren.add(toNode(r, repKids));
    }
    for (final d in (childrenByParent[_liveboxMac] ?? const <ServerDevice>[])) {
      rootChildren.add(toNode(d, const []));
    }

    return LiveboxTopologyNode(
      id: _liveboxMac,
      name: _liveboxModel,
      role: 'livebox',
      linkType: 'root',
      interfaceLabel: 'Passerelle Orange',
      ipAddress: _liveboxIp,
      deviceType: 'Livebox',
      active: _connected,
      children: rootChildren,
    );
  }

  List<Map<String, dynamic>> listEventsJson({int limit = 150, String? mac}) =>
      db.listEvents(limit: limit, mac: mac).map((e) => e.toJson()).toList();

  Future<Map<String, dynamic>> updateLiveboxConfig({
    required String url,
    required String username,
    String? password,
    required bool demoMode,
  }) async {
    final effectivePassword = (password != null && password.isNotEmpty)
        ? password
        : _liveboxConfig.password;

    _liveboxConfig = LiveboxCredentials(
      url: url.trim().isNotEmpty ? url.trim() : 'http://livebox.home/',
      username: username.trim().isNotEmpty ? username.trim() : 'admin',
      password: effectivePassword,
      demoMode: demoMode,
    );
    await vault.saveLiveboxCredentials(_liveboxConfig);
    await _startSessionForCurrentConfig();
    return {
      'saved': true,
      'config': _liveboxConfig.toRedactedJson(),
      'status': _statusPayload(),
    };
  }

  Future<Map<String, dynamic>> updateSmtpConfig({
    required bool enabled,
    required String host,
    required int port,
    required bool useSsl,
    required bool allowInsecure,
    required String username,
    String? password,
    required String fromAddress,
    required String toAddresses,
  }) async {
    final effectivePassword = (password != null && password.isNotEmpty)
        ? password
        : _smtpConfig.password;

    _smtpConfig = SmtpConfig(
      enabled: enabled,
      host: host.trim(),
      port: port,
      useSsl: useSsl,
      allowInsecure: allowInsecure,
      username: username.trim(),
      password: effectivePassword,
      fromAddress: fromAddress.trim(),
      toAddresses: toAddresses.trim(),
    );
    await vault.saveSmtpConfig(_smtpConfig);
    return {
      'saved': true,
      'config': _smtpConfig.toRedactedJson(),
    };
  }

  Future<void> sendTestEmail({SmtpConfig? override}) async {
    final cfg = override ?? _smtpConfig;
    await emailNotifier.sendTestEmail(cfg);
  }

  void _broadcast(String type, Map<String, dynamic> data) {
    if (!_sseController.isClosed) {
      _sseController.add({'type': type, 'data': data});
    }
  }

  Future<void> dispose() async {
    _running = false;
    await _stopCurrentLoop();
    await _sseController.close();
    _demoDb?.close();
    _demoDb = null;
    _liveDb.close();
  }
}
