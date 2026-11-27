import 'dart:io';

import 'package:livebox_client/livebox_client.dart';
import 'package:livebox_monitor_server/models/server_models.dart';
import 'package:livebox_monitor_server/services/email_notifier.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';
import 'package:livebox_monitor_server/storage/monitor_database.dart';
import 'package:livebox_monitor_server/storage/secret_vault.dart';
import 'package:livebox_monitor_server/utils/base_path.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  group('ReadOnlyLiveboxClient strict read-only guard', () {
    final session = LiveboxSession('http://127.0.0.1:9/');
    final client = ReadOnlyLiveboxClient(session);

    for (final forbidden in const [
      'set',
      'setName',
      'reboot',
      'reset',
      'destroyDevice',
      'setPortForwarding',
      'deletePortForwarding',
      'sendWakeOnLan',
      'addRule',
    ]) {
      test('blocks write method "$forbidden" with UnsupportedError', () {
        expect(
          () => client.readOnlyCall('NMC', method: forbidden),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => client.readOnlyCallRaw('NMC', method: forbidden),
          throwsA(isA<UnsupportedError>()),
        );
      });
    }

    test('allowlist contains only read-only methods', () {
      for (final m in ReadOnlyLiveboxClient.allowedReadOnlyMethods) {
        expect(m.startsWith('set'), isFalse);
        expect(m.startsWith('delete'), isFalse);
        expect(m, isNot('reboot'));
        expect(m, isNot('reset'));
      }
    });
  });

  group('SecretVault AES-256-GCM encryption', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('lbm_vault_test_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('encrypts and decrypts Livebox & SMTP credentials without plaintext on disk',
        () async {
      const secretLbPass = 'SuperSecretLivebox#2026!';
      const secretSmtpPass = 'SmtpUltraSecret#99!';

      final vault = SecretVault(
        dataDir: tmpDir.path,
        explicitKey: 'unit-test-master-key-256bit',
      );
      await vault.initialize();

      await vault.saveLiveboxCredentials(
        const LiveboxCredentials(
          url: 'http://192.168.1.1/',
          username: 'admin',
          password: secretLbPass,
          demoMode: false,
        ),
      );
      await vault.saveSmtpConfig(
        const SmtpConfig(
          enabled: true,
          host: 'smtp.example.org',
          port: 587,
          username: 'alerts@example.org',
          password: secretSmtpPass,
          fromAddress: 'alerts@example.org',
          toAddresses: 'owner@example.org',
        ),
      );

      final rawDisk = File(vault.vaultPath).readAsStringSync();
      expect(rawDisk, isNot(contains(secretLbPass)));
      expect(rawDisk, isNot(contains(secretSmtpPass)));
      expect(rawDisk, contains('AES-256-GCM'));

      // Re-open with a fresh vault instance using the same master key
      final reopened = SecretVault(
        dataDir: tmpDir.path,
        explicitKey: 'unit-test-master-key-256bit',
      );
      final loadedLb = await reopened.loadLiveboxCredentials();
      final loadedSmtp = await reopened.loadSmtpConfig();

      expect(loadedLb?.password, equals(secretLbPass));
      expect(loadedLb?.url, equals('http://192.168.1.1/'));
      expect(loadedSmtp.password, equals(secretSmtpPass));
      expect(loadedSmtp.toAddresses, equals('owner@example.org'));
    });
  });

  group('MonitorDatabase SQLite persistence', () {
    late MonitorDatabase db;

    setUp(() {
      db = MonitorDatabase.openInMemory();
    });

    tearDown(() {
      db.close();
    });

    test('tracks new devices, preserves known/unknown trust, presence & bandwidth', () {
      const t0 = 1700000000000;
      final incoming = ServerDevice(
        mac: 'aa:bb:cc:11:22:33',
        name: 'MacBook-Pro',
        vendor: 'Apple',
        deviceType: 'Computer',
        ipAddress: '192.168.1.25',
        active: true,
        linkType: 'wifi6',
        interfaceName: 'Wi-Fi 6 GHz',
        firstSeenMs: t0,
        lastSeenMs: t0,
        lastChangedMs: t0,
      );

      final first = db.upsertDevice(incoming, nowMs: t0);
      expect(first.isNew, isTrue);
      expect(first.device.mac, equals('AA:BB:CC:11:22:33'));
      expect(first.device.trust, equals(DeviceTrust.unknown));

      // Tag as known + note
      final tagged = db.setDeviceTrust(
        'aa:bb:cc:11:22:33',
        DeviceTrust.known,
        note: 'Poste principal',
      );
      expect(tagged?.trust, equals(DeviceTrust.known));
      expect(tagged?.note, equals('Poste principal'));

      // Subsequent Livebox update (default unknown) must NOT overwrite trust or note
      final second = db.upsertDevice(
        incoming.copyWith(active: false),
        nowMs: t0 + 3600000, // offline after 1h
      );
      expect(second.isNew, isFalse);
      expect(second.presenceChanged, isTrue);
      expect(second.device.trust, equals(DeviceTrust.known));
      expect(second.device.note, equals('Poste principal'));

      // Presence over 2h window (1h online, 1h offline => 50%)
      final timeline = db.getPresenceTimeline(
        'AA:BB:CC:11:22:33',
        sinceMs: t0,
        untilMs: t0 + 7200000,
      );
      expect(timeline.spans.length, equals(2));
      expect(timeline.uptimePercent, closeTo(50.0, 0.1));

      // Bandwidth samples
      db.updateDeviceBandwidth(
        mac: 'AA:BB:CC:11:22:33',
        rxBytes: 1000000,
        txBytes: 250000,
        rxBytesPerSec: 500000,
        txBytesPerSec: 125000,
        tsMs: t0 + 60000,
      );
      final bw = db.getBandwidthHistory('AA:BB:CC:11:22:33', sinceMs: t0);
      expect(bw.length, equals(1));
      expect(bw.first.rxBytesPerSec, equals(500000));
    });
  });

  group('LiveboxTopologyParser', () {
    test('parses Livebox -> Repeater -> Eth/Wi-Fi -> Devices hierarchy', () {
      final rawTopology = [
        {
          'Key': 'HGW',
          'Children': [
            {
              'Key': 'lan',
              'Children': [
                {
                  'Key': 'ETH0',
                  'Name': 'ETH0',
                  'Children': [
                    {
                      'Key': 'AA:BB:CC:10:00:01',
                      'Name': 'Répéteur Salon',
                      'DeviceType': 'SAH AP',
                      'InterfaceType': 'Ethernet',
                      'InterfaceName': 'eth0',
                      'IPAddress': '192.168.1.10',
                      'Active': true,
                      'Children': [
                        {
                          'Key': 'F0:99:B6:EE:55:05',
                          'Name': 'iPhone-16',
                          'DeviceType': 'Phone',
                          'InterfaceType': 'Wi-Fi',
                          'OperatingFrequencyBand': '5GHz',
                          'SignalStrength': -52,
                          'IPAddress': '192.168.1.38',
                          'Active': true,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ];

      final root = LiveboxTopologyParser.parseFromTopology(
        rawTopology: rawTopology,
        liveboxModel: 'Livebox W7',
        liveboxIp: '192.168.1.1',
        liveboxMac: 'AA:BB:CC:00:00:01',
      );

      expect(root.role, equals('livebox'));
      expect(root.children.length, equals(1));
      final rep = root.children.first;
      expect(rep.role, equals('repeater'));
      expect(rep.linkType, equals('eth'));
      expect(rep.children.length, equals(1));
      final phone = rep.children.first;
      expect(phone.role, equals('device'));
      expect(phone.linkType, equals('wifi5'));
      expect(phone.rssi, equals(-52));
    });
  });

  group('LiveboxMonitorService + EmailNotifier integration (Demo Mode)', () {
    late Directory tmpDir;
    late LiveboxMonitorService service;
    final sentMessages = <Message>[];

    setUp(() async {
      tmpDir = Directory.systemTemp.createTempSync('lbm_service_test_');
      sentMessages.clear();
      final vault = SecretVault(
        dataDir: tmpDir.path,
        explicitKey: 'service-test-key',
      );
      await vault.initialize();
      await vault.saveLiveboxCredentials(
        const LiveboxCredentials(url: 'http://livebox.home/', demoMode: true),
      );
      await vault.saveSmtpConfig(
        const SmtpConfig(
          enabled: true,
          host: 'smtp.local',
          port: 1025,
          allowInsecure: true,
          fromAddress: 'livebox@local',
          toAddresses: 'admin@local',
        ),
      );

      final notifier = EmailNotifier(
        sender: (Message msg, SmtpServer server) async {
          sentMessages.add(msg);
        },
      );
      service = LiveboxMonitorService(
        db: MonitorDatabase.openInMemory(),
        vault: vault,
        emailNotifier: notifier,
        dashboardUrl: 'http://localhost:8080',
      );
      await service.start();
    });

    tearDown(() async {
      await service.dispose();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('seeds demo devices/topology and sends SMTP alert on new unknown device',
        () async {
      final overview = service.getOverview();
      expect(overview['demoMode'], isTrue);
      expect(overview['readOnlyEnforced'], isTrue);
      expect((overview['stats'] as Map)['totalDevices'], greaterThanOrEqualTo(8));

      final topo = service.getTopology();
      expect(topo['role'], equals('livebox'));
      expect((topo['children'] as List), isNotEmpty);

      final sseCaptured = <Map<String, dynamic>>[];
      final sub = service.sseEvents.listen(sseCaptured.add);

      final newDev = await service.simulateNewDevice();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(newDev.trust, equals(DeviceTrust.unknown));
      expect(sentMessages.length, equals(1));
      expect(sentMessages.first.subject, contains(newDev.mac));
      expect(sentMessages.first.recipients, contains('admin@local'));
      expect(
        sseCaptured.any((e) => e['type'] == 'new_device'),
        isTrue,
      );

      // User marks the newly discovered device as known
      final updated = service.tagDevice(newDev.mac, DeviceTrust.known, note: 'OK');
      expect(updated?.trust, equals(DeviceTrust.known));
      expect(updated?.note, equals('OK'));
    });

    test('switching from Demo Mode to real Livebox clears all demo data and preserves real devices',
        () async {
      // Confirm demo mode has seeded devices
      expect(service.isDemoMode, isTrue);
      expect(service.listDevicesJson().length, greaterThanOrEqualTo(10));

      // Switch to real Livebox mode (empty password -> stays disconnected cleanly without network)
      await service.updateLiveboxConfig(
        url: 'http://192.168.1.1/',
        username: 'admin',
        password: '',
        demoMode: false,
      );

      expect(service.isDemoMode, isFalse);
      // Zero demo devices, zero demo events, and liveboxModel reset
      expect(service.listDevicesJson(), isEmpty);
      expect(service.listEventsJson(), isEmpty);
      final ov = service.getOverview();
      expect(ov['liveboxModel'], equals('Livebox'));
      expect(ov['wanIp'], isEmpty);
      expect((service.getTopology()['children'] as List), isEmpty);

      // Verify purgeDemoArtifacts removes legacy demo MACs while keeping real ones
      final realMac = '12:34:56:78:9A:BC';
      service.db.upsertDevice(
        ServerDevice(
          mac: realMac,
          name: 'Mon-Vrai-PC',
          vendor: 'RealVendor',
          deviceType: 'Computer',
          ipAddress: '192.168.1.42',
          active: true,
          linkType: 'eth',
          interfaceName: 'Ethernet ETH1',
          trust: DeviceTrust.known,
          firstSeenMs: 1700000000000,
          lastSeenMs: 1700000000000,
          lastChangedMs: 1700000000000,
        ),
      );
      service.db.upsertDevice(
        ServerDevice(
          mac: LiveboxMonitorService.demoSeedMacs.first,
          name: 'Répéteur Wi-Fi 6 Salon',
          vendor: 'Sagemcom',
          deviceType: 'Wi-Fi Repeater',
          ipAddress: '192.168.1.10',
          active: true,
          linkType: 'eth',
          interfaceName: 'Eth 10G / 1',
          firstSeenMs: 1700000000000,
          lastSeenMs: 1700000000000,
          lastChangedMs: 1700000000000,
        ),
      );

      final purged = service.db.purgeDemoArtifacts(
        LiveboxMonitorService.demoSeedMacs,
        simulatedPrefix: 'DE:AD:BE:EF:',
      );
      expect(purged, equals(1));
      final remaining = service.listDevicesJson();
      expect(remaining.length, equals(1));
      expect(remaining.first['mac'], equals(realMac));
    });

    test('parses real Livebox data-wrapped Statistics, changed, and HomeLan events',
        () async {
      await service.updateLiveboxConfig(
        url: 'http://192.168.1.1/',
        username: 'admin',
        password: '',
        demoMode: false,
      );

      const mac = 'AA:11:22:33:44:55';
      service.db.upsertDevice(
        ServerDevice(
          mac: mac,
          name: 'PC-Bureau',
          vendor: 'Apple',
          deviceType: 'Computer',
          ipAddress: '192.168.1.40',
          active: true,
          linkType: 'eth',
          interfaceName: 'Ethernet ETH1',
          firstSeenMs: 1700000000000,
          lastSeenMs: 1700000000000,
          lastChangedMs: 1700000000000,
        ),
      );

      final t1 = DateTime.now().subtract(const Duration(seconds: 5)).toUtc().toIso8601String();
      final t2 = DateTime.now().toUtc().toIso8601String();

      // 1st Statistics event (baseline) wrapped in `data` like real Orange Livebox
      await service.processLiveboxEvent({
        'data': {
          'handler': 'Devices.Device.$mac',
          'object': {
            'reason': 'Statistics',
            'attributes': {
              mac.toLowerCase(): {
                'RxBytes': 1000000,
                'TxBytes': 200000,
                'Timestamp': t1,
              },
            },
          },
        },
      });

      // 2nd Statistics event 5s later (+500 KB Rx, +100 KB Tx => ~100 KB/s Rx, ~20 KB/s Tx)
      await service.processLiveboxEvent({
        'data': {
          'handler': 'Devices.Device.$mac',
          'object': {
            'reason': 'Statistics',
            'attributes': {
              mac: {
                'RxBytes': 1500000,
                'TxBytes': 300000,
                'Timestamp': t2,
              },
            },
          },
        },
      });

      final updated = service.db.getDevice(mac)!;
      expect(updated.rxBytesPerSec, greaterThan(50000));
      expect(updated.txBytesPerSec, greaterThan(10000));
      final stats = service.getOverview()['stats'] as Map;
      expect(stats['totalRxBytesPerSec'] as num, greaterThan(50000));

      // Real Livebox HomeLan interface event wrapped in `data`
      await service.processLiveboxEvent({
        'data': {
          'handler': 'HomeLan.Interface.eth0.Stats',
          'object': {
            'reason': 'changed',
            'attributes': {
              'BytesReceived': 999999,
              'BytesSent': 111111,
            },
          },
        },
      });

      // Real Livebox device_updated event with nested MAC attributes
      await service.processLiveboxEvent({
        'data': {
          'handler': 'Devices.Device.$mac',
          'object': {
            'reason': 'device_updated',
            'attributes': {
              mac: {
                'Name': 'Mac-Studio-ETH',
                'IPAddress': '192.168.1.40',
                'Active': true,
              },
            },
          },
        },
      });

      expect(service.db.getDevice(mac)!.name, equals('Mac-Studio-ETH'));
      final events = service.listEventsJson();
      expect(events.any((e) => e['reason'] == 'Statistics'), isTrue);
      expect(events.any((e) => e['reason'] == 'HomeLan'), isTrue);
      expect(events.any((e) => e['reason'] == 'device_updated'), isTrue);

      // Fresh 5s Wi-Fi sample (~433 Mbps = 54.125 MB/s) must NOT be clobbered
      // by a slower 60s Devices.Device Statistics average (~90 Mbps)
      service.recordWifiStationSample(
        mac: mac,
        rxBytes: 500000000,
        txBytes: 20000000,
        rxBytesPerSec: 54125000,
        txBytesPerSec: 2500000,
      );
      final t3 = DateTime.now().add(const Duration(seconds: 5)).toUtc().toIso8601String();
      await service.processLiveboxEvent({
        'data': {
          'handler': 'Devices.Device.$mac',
          'object': {
            'reason': 'Statistics',
            'attributes': {
              mac: {
                'RxBytes': 1550000,
                'TxBytes': 310000,
                'Timestamp': t3,
              },
            },
          },
        },
      });
      expect(service.db.getDevice(mac)!.rxBytesPerSec, closeTo(54125000, 1));
      final ovStats = service.getOverview()['stats'] as Map;
      expect(ovStats['totalRxBytesPerSec'] as num, closeTo(54125000, 1));
    });
  });

  group('BasePathConfig (ProxyPass support)', () {
    test('normalizes various BASE_PATH inputs cleanly', () {
      expect(BasePathConfig.normalize(null), equals(''));
      expect(BasePathConfig.normalize(''), equals(''));
      expect(BasePathConfig.normalize('/'), equals(''));
      expect(BasePathConfig.normalize('livebox'), equals('/livebox'));
      expect(BasePathConfig.normalize('/livebox/'), equals('/livebox'));
      expect(BasePathConfig.normalize('//tools//livebox///'), equals('/tools/livebox'));
    });

    test('rewrites index.html asset URLs and injects __LBM_BASE_PATH__', () {
      final cfg = BasePathConfig.fromRaw('/livebox/');
      const sample = '''
<head>
  <link rel="icon" href="/favicon.png" />
  <link rel="stylesheet" href="/styles.css" />
</head>
<body><img src="/favicon.png" /><script src="/app.js"></script></body>
''';
      final rewritten = cfg.rewriteIndexHtml(sample);
      expect(rewritten, contains('window.__LBM_BASE_PATH__="/livebox";'));
      expect(rewritten, contains('href="/livebox/styles.css"'));
      expect(rewritten, contains('src="/livebox/app.js"'));
      expect(rewritten, contains('href="/livebox/favicon.png"'));
      expect(rewritten, contains('src="/livebox/favicon.png"'));
    });

    test('stripPrefixMiddleware handles exact prefix, nested routes, and already-stripped passthrough',
        () async {
      final cfg = BasePathConfig.fromRaw('/tools/livebox');
      final handler = cfg.buildShelfMiddleware()(
        (shelf.Request req) => shelf.Response.ok('/${req.url.path}'),
      );

      final r1 = await handler(
        shelf.Request('GET', Uri.parse('http://localhost/tools/livebox')),
      );
      expect(await r1.readAsString(), equals('/'));

      final r2 = await handler(
        shelf.Request('GET', Uri.parse('http://localhost/tools/livebox/api/health')),
      );
      expect(await r2.readAsString(), equals('/api/health'));

      // Already-stripped ProxyPass or internal Docker health check passes through
      final r3 = await handler(
        shelf.Request('GET', Uri.parse('http://localhost/api/health')),
      );
      expect(await r3.readAsString(), equals('/api/health'));
    });
  });
}
