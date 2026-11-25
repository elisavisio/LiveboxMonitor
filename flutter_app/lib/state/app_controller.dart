import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../data/api/demo_livebox_repository.dart';
import '../data/api/livebox_repository.dart';
import '../data/api/livebox_session.dart';
import '../data/api/real_livebox_repository.dart';
import '../data/models/models.dart';
import '../data/storage/profile_store.dart';

class AppController extends ChangeNotifier {
  final AppPreferencesStore _store;

  AppController({AppPreferencesStore? store})
      : _store = store ?? AppPreferencesStore();

  // Preferences
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.en;
  int _statsIntervalMs = 2000;
  List<ConnectionProfile> _profiles = const [
    ConnectionProfile(
      id: 'default',
      name: 'Home Livebox',
      url: 'http://livebox.home/',
      username: 'admin',
    ),
  ];
  String _activeProfileId = 'default';

  // Connection state
  LiveboxRepository? _repo;
  bool _isConnecting = false;
  bool _isRefreshing = false;
  String? _connectionError;
  List<String> _connectionDebugLogs = const [];
  Timer? _pollingTimer;
  bool _pollingPaused = false;

  // Domain state
  LiveboxInfo? _info;
  List<NetworkInterfaceInfo> _interfaces = [];
  List<NetworkDevice> _devices = [];
  final Map<String, List<TrafficSample>> _trafficHistory = {};
  final List<LiveboxEvent> _events = [];
  DhcpConfig? _dhcpConfig;
  List<DhcpBinding> _dhcpBindings = [];
  List<NatPatRule> _natPatRules = [];
  List<PtfRule> _ptfRules = [];
  DmzConfig _dmz = const DmzConfig(enabled: false, destinationIp: '');
  FirewallState? _firewall;
  List<PhoneCallEntry> _calls = [];
  List<PhoneContact> _contacts = [];
  List<RepeaterInfo> _repeaters = [];
  List<TvDecoderInfo> _tvDecoders = [];
  List<WifiBandConfig> _wifiBands = [];
  List<RebootEntry> _rebootHistory = [];
  List<DynDnsHost> _dynDnsHosts = [];
  List<StaticRoute> _staticRoutes = [];
  SpeedTestResult? _lastSpeedTest;

  // Getters
  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings(_language);
  int get statsIntervalMs => _statsIntervalMs;
  List<ConnectionProfile> get profiles => List.unmodifiable(_profiles);
  ConnectionProfile get activeProfile => _profiles.firstWhere(
        (p) => p.id == _activeProfileId,
        orElse: () => _profiles.first,
      );

  bool get isConnected => _repo != null;
  bool get isDemo => _repo?.isDemo ?? false;
  String get connectionLabel => _repo?.connectionLabel ?? '';
  bool get isConnecting => _isConnecting;
  bool get isRefreshing => _isRefreshing;
  String? get connectionError => _connectionError;
  List<String> get connectionDebugLogs => List.unmodifiable(_connectionDebugLogs);
  bool get pollingPaused => _pollingPaused;

  LiveboxInfo? get info => _info;
  List<NetworkInterfaceInfo> get interfaces => List.unmodifiable(_interfaces);
  List<NetworkDevice> get devices => List.unmodifiable(_devices);
  Map<String, List<TrafficSample>> get trafficHistory => _trafficHistory;
  List<LiveboxEvent> get events => List.unmodifiable(_events);
  DhcpConfig? get dhcpConfig => _dhcpConfig;
  List<DhcpBinding> get dhcpBindings => List.unmodifiable(_dhcpBindings);
  List<NatPatRule> get natPatRules => List.unmodifiable(_natPatRules);
  List<PtfRule> get ptfRules => List.unmodifiable(_ptfRules);
  DmzConfig get dmz => _dmz;
  FirewallState? get firewall => _firewall;
  List<PhoneCallEntry> get calls => List.unmodifiable(_calls);
  List<PhoneContact> get contacts => List.unmodifiable(_contacts);
  List<RepeaterInfo> get repeaters => List.unmodifiable(_repeaters);
  List<TvDecoderInfo> get tvDecoders => List.unmodifiable(_tvDecoders);
  List<WifiBandConfig> get wifiBands => List.unmodifiable(_wifiBands);
  List<RebootEntry> get rebootHistory => List.unmodifiable(_rebootHistory);
  List<DynDnsHost> get dynDnsHosts => List.unmodifiable(_dynDnsHosts);
  List<StaticRoute> get staticRoutes => List.unmodifiable(_staticRoutes);
  SpeedTestResult? get lastSpeedTest => _lastSpeedTest;

  TrafficSample? get latestWanTraffic {
    final wan = _interfaces.where((i) => i.type == 'wan').firstOrNull;
    final key = wan?.key ?? (_interfaces.isNotEmpty ? _interfaces.first.key : null);
    if (key == null) return null;
    final list = _trafficHistory[key];
    return (list != null && list.isNotEmpty) ? list.last : null;
  }

  Future<void> initialize() async {
    _themeMode = await _store.loadThemeMode();
    _language = await _store.loadLanguage();
    _statsIntervalMs = await _store.loadStatsIntervalMs();
    _profiles = await _store.loadProfiles();
    final activeId = await _store.loadActiveProfileId();
    if (activeId != null && _profiles.any((p) => p.id == activeId)) {
      _activeProfileId = activeId;
    } else {
      _activeProfileId = _profiles.first.id;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _store.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    await _store.saveLanguage(lang);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_language == AppLanguage.en ? AppLanguage.fr : AppLanguage.en);
  }

  Future<void> selectProfile(String id) async {
    if (_profiles.any((p) => p.id == id)) {
      _activeProfileId = id;
      await _store.saveActiveProfileId(id);
      notifyListeners();
    }
  }

  Future<void> upsertProfile(ConnectionProfile profile) async {
    final list = List<ConnectionProfile>.of(_profiles);
    final idx = list.indexWhere((p) => p.id == profile.id);
    if (idx != -1) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    _profiles = list;
    _activeProfileId = profile.id;
    await _store.saveProfiles(_profiles);
    await _store.saveActiveProfileId(_activeProfileId);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    if (_profiles.length <= 1) return;
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_activeProfileId == id) {
      _activeProfileId = _profiles.first.id;
      await _store.saveActiveProfileId(_activeProfileId);
    }
    await _store.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<bool> connectLive({
    required String url,
    required String username,
    required String password,
    required String profileName,
  }) async {
    _isConnecting = true;
    _connectionError = null;
    _connectionDebugLogs = const [];
    notifyListeners();

    final session = LiveboxSession(url);
    final code = await session.signIn(username, password);
    _connectionDebugLogs = List.of(session.debugLogs);
    if (code != 1) {
      _isConnecting = false;
      final baseMsg = code == 0
          ? strings.t(
              'Authentication failed. Please check your username and Livebox password.',
              'Échec d\'authentification. Vérifiez l\'identifiant et le mot de passe Livebox.',
            )
          : strings.t(
              'Unable to reach Livebox at $url. Verify the URL (or try http://192.168.1.1/) or check macOS Local Network permission.',
              'Impossible de joindre la Livebox sur $url. Vérifiez l\'URL (ou essayez http://192.168.1.1/) ou l\'autorisation Réseau local macOS.',
            );
      final detail = session.lastErrorDetail;
      _connectionError = detail != null ? '$baseMsg\n$detail' : baseMsg;
      notifyListeners();
      return false;
    }

    _repo = RealLiveboxRepository(session, label: '$profileName · $url');
    await _bootstrapAfterConnect();
    _isConnecting = false;
    notifyListeners();
    return true;
  }

  Future<void> connectDemo() async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    _repo = DemoLiveboxRepository();
    await _bootstrapAfterConnect();
    _isConnecting = false;
    notifyListeners();
  }

  Future<void> _bootstrapAfterConnect() async {
    _trafficHistory.clear();
    _events.clear();
    await refreshAll();

    // Pre-seed 16 initial traffic points in Demo mode so graphs look alive immediately
    if (isDemo && _interfaces.isNotEmpty) {
      final keys = _interfaces.map((e) => e.key).toList();
      for (int i = 0; i < 16; i++) {
        final samples = await _repo!.sampleTraffic(keys);
        final backdated = DateTime.now().subtract(Duration(seconds: (16 - i) * 2));
        for (final entry in samples.entries) {
          final list = _trafficHistory.putIfAbsent(entry.key, () => []);
          list.add(TrafficSample(
            timestamp: backdated,
            downMbps: entry.value.downMbps,
            upMbps: entry.value.upMbps,
          ));
        }
      }
      final evs = await _repo!.pollEvents();
      _events.insertAll(0, evs.reversed);
    }

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingPaused = false;
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _statsIntervalMs),
      (_) => _pollTick(),
    );
  }

  void togglePollingPaused() {
    _pollingPaused = !_pollingPaused;
    notifyListeners();
  }

  Future<void> _pollTick() async {
    if (_repo == null || _pollingPaused) return;
    try {
      final keys = _interfaces.map((e) => e.key).toList();
      if (keys.isNotEmpty) {
        final samples = await _repo!.sampleTraffic(keys);
        for (final entry in samples.entries) {
          final list = _trafficHistory.putIfAbsent(entry.key, () => []);
          list.add(entry.value);
          if (list.length > 60) list.removeAt(0);
        }
      }
      final newEvents = await _repo!.pollEvents();
      if (newEvents.isNotEmpty) {
        _events.insertAll(0, newEvents.reversed);
        if (_events.length > 500) {
          _events.removeRange(500, _events.length);
        }
      }
      if (isDemo) {
        _info = await _repo!.fetchLiveboxInfo();
        _interfaces = await _repo!.fetchInterfaces();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await _repo?.disconnect();
    _repo = null;
    _info = null;
    _interfaces = [];
    _devices = [];
    _trafficHistory.clear();
    _events.clear();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final repo = _repo;
    if (repo == null) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        repo.fetchLiveboxInfo(),
        repo.fetchInterfaces(),
        repo.fetchDevices(),
        repo.fetchDhcpConfig(),
        repo.fetchDhcpBindings(),
        repo.fetchNatPatRules(),
        repo.fetchPtfRules(),
        repo.fetchDmz(),
        repo.fetchFirewall(),
        repo.fetchCallLog(),
        repo.fetchContacts(),
        repo.fetchRepeaters(),
        repo.fetchTvDecoders(),
        repo.fetchWifiBands(),
        repo.fetchRebootHistory(),
        repo.fetchDynDnsHosts(),
        repo.fetchStaticRoutes(),
      ]);

      _info = results[0] as LiveboxInfo;
      _interfaces = results[1] as List<NetworkInterfaceInfo>;
      _devices = results[2] as List<NetworkDevice>;
      _dhcpConfig = results[3] as DhcpConfig;
      _dhcpBindings = results[4] as List<DhcpBinding>;
      _natPatRules = results[5] as List<NatPatRule>;
      _ptfRules = results[6] as List<PtfRule>;
      _dmz = results[7] as DmzConfig;
      _firewall = results[8] as FirewallState;
      _calls = results[9] as List<PhoneCallEntry>;
      _contacts = results[10] as List<PhoneContact>;
      _repeaters = results[11] as List<RepeaterInfo>;
      _tvDecoders = results[12] as List<TvDecoderInfo>;
      _wifiBands = results[13] as List<WifiBandConfig>;
      _rebootHistory = results[14] as List<RebootEntry>;
      _dynDnsHosts = results[15] as List<DynDnsHost>;
      _staticRoutes = results[16] as List<StaticRoute>;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // ---- Device actions ----
  Future<void> renameDevice(String mac, String name) async {
    await _repo?.renameDevice(mac, name);
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  Future<void> setDeviceType(String mac, String type) async {
    await _repo?.setDeviceType(mac, type);
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  Future<void> setDeviceBlocked(String mac, bool blocked) async {
    await _repo?.setDeviceBlocked(mac, blocked);
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  Future<void> wakeOnLan(String mac) async {
    await _repo?.wakeOnLan(mac);
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  Future<void> deleteDevice(String mac) async {
    await _repo?.deleteDevice(mac);
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  // ---- DHCP ----
  Future<void> saveDhcpConfig(DhcpConfig config) async {
    await _repo?.saveDhcpConfig(config);
    _dhcpConfig = await _repo!.fetchDhcpConfig();
    notifyListeners();
  }

  Future<void> addDhcpBinding(String mac, String ip) async {
    await _repo?.addDhcpBinding(mac, ip);
    _dhcpBindings = await _repo!.fetchDhcpBindings();
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  Future<void> deleteDhcpBinding(String mac) async {
    await _repo?.deleteDhcpBinding(mac);
    _dhcpBindings = await _repo!.fetchDhcpBindings();
    _devices = await _repo!.fetchDevices();
    notifyListeners();
  }

  // ---- NAT/PAT/PTF/DMZ ----
  Future<void> saveNatPatRule(NatPatRule rule) async {
    await _repo?.saveNatPatRule(rule);
    _natPatRules = await _repo!.fetchNatPatRules();
    notifyListeners();
  }

  Future<void> deleteNatPatRule(NatPatRule rule) async {
    await _repo?.deleteNatPatRule(rule);
    _natPatRules = await _repo!.fetchNatPatRules();
    notifyListeners();
  }

  Future<void> savePtfRule(PtfRule rule) async {
    await _repo?.savePtfRule(rule);
    _ptfRules = await _repo!.fetchPtfRules();
    notifyListeners();
  }

  Future<void> deletePtfRule(String id) async {
    await _repo?.deletePtfRule(id);
    _ptfRules = await _repo!.fetchPtfRules();
    notifyListeners();
  }

  Future<void> saveDmz(DmzConfig config) async {
    await _repo?.saveDmz(config);
    _dmz = await _repo!.fetchDmz();
    notifyListeners();
  }

  // ---- Firewall ----
  Future<void> setFirewallLevels(String v4, String v6) async {
    await _repo?.setFirewallLevels(v4, v6);
    _firewall = await _repo!.fetchFirewall();
    notifyListeners();
  }

  Future<void> setRespondToPing(bool v4, bool v6) async {
    await _repo?.setRespondToPing(v4, v6);
    _firewall = await _repo!.fetchFirewall();
    notifyListeners();
  }

  Future<void> saveFirewallRule(FirewallRule rule) async {
    await _repo?.saveFirewallRule(rule);
    _firewall = await _repo!.fetchFirewall();
    notifyListeners();
  }

  Future<void> deleteFirewallRule(String id) async {
    await _repo?.deleteFirewallRule(id);
    _firewall = await _repo!.fetchFirewall();
    notifyListeners();
  }

  // ---- Phone / VoIP ----
  Future<void> deleteCall(String id) async {
    await _repo?.deleteCall(id);
    _calls = await _repo!.fetchCallLog();
    notifyListeners();
  }

  Future<void> ringPhones() async {
    await _repo?.ringPhones();
  }

  Future<void> saveContact(PhoneContact contact) async {
    await _repo?.saveContact(contact);
    _contacts = await _repo!.fetchContacts();
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    await _repo?.deleteContact(id);
    _contacts = await _repo!.fetchContacts();
    notifyListeners();
  }

  // ---- Repeaters ----
  Future<void> setRepeaterWifi(String mac, bool enabled) async {
    await _repo?.setRepeaterWifi(mac, enabled);
    _repeaters = await _repo!.fetchRepeaters();
    notifyListeners();
  }

  Future<void> rebootRepeater(String mac) async {
    await _repo?.rebootRepeater(mac);
    _repeaters = await _repo!.fetchRepeaters();
    notifyListeners();
  }

  // ---- TV Decoders ----
  Future<void> sendTvRemoteKey(String decoderKey, int keyCode) async {
    if (_repo == null) return;
    final updated = await _repo!.sendTvRemoteKey(decoderKey, keyCode);
    _tvDecoders = _tvDecoders.map((d) => d.key == decoderKey ? updated : d).toList();
    notifyListeners();
  }

  Future<void> zapTvChannel(String decoderKey, int number, String name) async {
    if (_repo == null) return;
    final updated = await _repo!.zapTvChannel(decoderKey, number, name);
    _tvDecoders = _tvDecoders.map((d) => d.key == decoderKey ? updated : d).toList();
    notifyListeners();
  }

  // ---- Actions & Tools ----
  Future<void> setGlobalWifi(bool enabled) async {
    await _repo?.setGlobalWifi(enabled);
    _info = await _repo!.fetchLiveboxInfo();
    _wifiBands = await _repo!.fetchWifiBands();
    notifyListeners();
  }

  Future<void> setGuestWifi(bool enabled, {int timerHours = 0}) async {
    await _repo?.setGuestWifi(enabled, timerHours: timerHours);
    _info = await _repo!.fetchLiveboxInfo();
    _wifiBands = await _repo!.fetchWifiBands();
    notifyListeners();
  }

  Future<void> setWifiScheduler(bool enabled) async {
    await _repo?.setWifiScheduler(enabled);
    _info = await _repo!.fetchLiveboxInfo();
    notifyListeners();
  }

  Future<void> saveWifiBand(WifiBandConfig band) async {
    await _repo?.saveWifiBand(band);
    _wifiBands = await _repo!.fetchWifiBands();
    notifyListeners();
  }

  Future<void> setLedBrightness(int level) async {
    await _repo?.setLedBrightness(level);
    _info = await _repo!.fetchLiveboxInfo();
    notifyListeners();
  }

  Future<void> setShowWifiPasswordOnScreen(bool show) async {
    await _repo?.setShowWifiPasswordOnScreen(show);
    _info = await _repo!.fetchLiveboxInfo();
    notifyListeners();
  }

  Future<void> rebootLivebox() async {
    await _repo?.rebootLivebox();
    _rebootHistory = await _repo!.fetchRebootHistory();
    _info = await _repo!.fetchLiveboxInfo();
    notifyListeners();
  }

  Future<void> addDynDnsHost(String service, String host, String user, String pass) async {
    await _repo?.addDynDnsHost(service, host, user, pass);
    _dynDnsHosts = await _repo!.fetchDynDnsHosts();
    notifyListeners();
  }

  Future<void> deleteDynDnsHost(String host) async {
    await _repo?.deleteDynDnsHost(host);
    _dynDnsHosts = await _repo!.fetchDynDnsHosts();
    notifyListeners();
  }

  Future<void> addStaticRoute(String destination, String gateway) async {
    await _repo?.addStaticRoute(destination, gateway);
    _staticRoutes = await _repo!.fetchStaticRoutes();
    notifyListeners();
  }

  Future<void> deleteStaticRoute(String id) async {
    await _repo?.deleteStaticRoute(id);
    _staticRoutes = await _repo!.fetchStaticRoutes();
    notifyListeners();
  }

  Future<void> triggerBackup() async => _repo?.triggerBackup();

  Future<void> triggerRestore() async => _repo?.triggerRestore();

  Future<SpeedTestResult?> runSpeedTest() async {
    if (_repo == null) return null;
    _lastSpeedTest = await _repo!.runSpeedTest();
    notifyListeners();
    return _lastSpeedTest;
  }

  Future<String> executeRawApi(
      String service, String method, Map<String, dynamic> params) async {
    if (_repo == null) return '{}';
    return _repo!.executeRawApi(service, method, params);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
