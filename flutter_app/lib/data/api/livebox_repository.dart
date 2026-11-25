import '../models/models.dart';

/// Unified repository abstraction implemented by both [RealLiveboxRepository]
/// (live HTTP sysbus + TV decoder API) and [DemoLiveboxRepository] (rich interactive simulation).
abstract class LiveboxRepository {
  bool get isDemo;
  String get connectionLabel;

  Future<void> disconnect();

  // Overview & Interfaces
  Future<LiveboxInfo> fetchLiveboxInfo();
  Future<List<NetworkInterfaceInfo>> fetchInterfaces();

  // Devices
  Future<List<NetworkDevice>> fetchDevices();
  Future<void> renameDevice(String mac, String newName);
  Future<void> setDeviceType(String mac, String newType);
  Future<void> setDeviceBlocked(String mac, bool blocked);
  Future<void> wakeOnLan(String mac);
  Future<void> deleteDevice(String mac);

  // Real-time traffic & events
  Future<Map<String, TrafficSample>> sampleTraffic(List<String> interfaceKeys);
  Future<Map<String, DeviceTrafficStats>> sampleDeviceTraffic(
      List<NetworkInterfaceInfo> interfaces);
  Future<List<LiveboxEvent>> pollEvents();

  // DHCP
  Future<DhcpConfig> fetchDhcpConfig();
  Future<void> saveDhcpConfig(DhcpConfig config);
  Future<List<DhcpBinding>> fetchDhcpBindings();
  Future<void> addDhcpBinding(String mac, String ip);
  Future<void> deleteDhcpBinding(String mac);

  // NAT / PAT / PTF / DMZ
  Future<List<NatPatRule>> fetchNatPatRules();
  Future<void> saveNatPatRule(NatPatRule rule);
  Future<void> deleteNatPatRule(NatPatRule rule);
  Future<List<PtfRule>> fetchPtfRules();
  Future<void> savePtfRule(PtfRule rule);
  Future<void> deletePtfRule(String id);
  Future<DmzConfig> fetchDmz();
  Future<void> saveDmz(DmzConfig config);

  // Firewall
  Future<FirewallState> fetchFirewall();
  Future<void> setFirewallLevels(String ipv4Level, String ipv6Level);
  Future<void> setRespondToPing(bool ipv4, bool ipv6);
  Future<void> saveFirewallRule(FirewallRule rule);
  Future<void> deleteFirewallRule(String id);

  // Phone / VoIP
  Future<List<PhoneCallEntry>> fetchCallLog();
  Future<void> deleteCall(String id);
  Future<void> ringPhones();
  Future<List<PhoneContact>> fetchContacts();
  Future<void> saveContact(PhoneContact contact);
  Future<void> deleteContact(String id);

  // Repeaters
  Future<List<RepeaterInfo>> fetchRepeaters();
  Future<void> setRepeaterWifi(String mac, bool enabled);
  Future<void> rebootRepeater(String mac);

  // TV Decoders
  Future<List<TvDecoderInfo>> fetchTvDecoders();
  Future<TvDecoderInfo> sendTvRemoteKey(String decoderKey, int keyCode);
  Future<TvDecoderInfo> zapTvChannel(String decoderKey, int channelNumber, String channelName);

  // Actions & Tools
  Future<List<WifiBandConfig>> fetchWifiBands();
  Future<void> setGlobalWifi(bool enabled);
  Future<void> setGuestWifi(bool enabled, {int timerHours = 0});
  Future<void> setWifiScheduler(bool enabled);
  Future<void> saveWifiBand(WifiBandConfig band);
  Future<void> setLedBrightness(int level);
  Future<void> setShowWifiPasswordOnScreen(bool show);
  Future<void> rebootLivebox();
  Future<List<RebootEntry>> fetchRebootHistory();
  Future<List<DynDnsHost>> fetchDynDnsHosts();
  Future<void> addDynDnsHost(String service, String hostname, String username, String password);
  Future<void> deleteDynDnsHost(String hostname);
  Future<List<StaticRoute>> fetchStaticRoutes();
  Future<void> addStaticRoute(String destination, String gateway);
  Future<void> deleteStaticRoute(String id);
  Future<void> triggerBackup();
  Future<void> triggerRestore();
  Future<SpeedTestResult> runSpeedTest();
  Future<String> executeRawApi(String service, String method, Map<String, dynamic> params);
}
