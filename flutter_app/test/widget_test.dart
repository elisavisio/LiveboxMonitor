import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livebox_monitor/core/l10n/app_strings.dart';
import 'package:livebox_monitor/core/utils/formatters.dart';
import 'package:livebox_monitor/data/api/demo_livebox_repository.dart';
import 'package:livebox_monitor/main.dart';
import 'package:livebox_monitor/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Formatters unit tests', () {
    test('formats bytes cleanly', () {
      expect(Formatters.bytes(512), '512 B');
      expect(Formatters.bytes(1024), '1.00 KB');
      expect(Formatters.bytes(1024 * 1024 * 2.5), '2.50 MB');
    });

    test('formats bitrates cleanly', () {
      expect(Formatters.bitsPerSec(0), '0 bps');
      expect(Formatters.bitsPerSec(1500), '1.5 Kbps');
      expect(Formatters.bitsPerSec(250000000), '250 Mbps');
    });

    test('formats durations cleanly', () {
      expect(Formatters.duration(45), '45s');
      expect(Formatters.duration(3665), '1h 01m');
      expect(Formatters.duration(90061), '1d 01h 01m');
    });

    test('computes RSSI bars accurately', () {
      expect(Formatters.rssiBars(null), 0);
      expect(Formatters.rssiBars(-48), 4);
      expect(Formatters.rssiBars(-60), 3);
      expect(Formatters.rssiBars(-72), 2);
      expect(Formatters.rssiBars(-82), 1);
    });
  });

  group('DemoLiveboxRepository unit tests', () {
    test('supports interactive device, TV remote, and API explorer operations', () async {
      final repo = DemoLiveboxRepository();
      final devices = await repo.fetchDevices();
      expect(devices.length, greaterThanOrEqualTo(10));

      final mac = devices.first.key;
      await repo.renameDevice(mac, 'Renamed MacBook');
      final updated = (await repo.fetchDevices()).firstWhere((d) => d.key == mac);
      expect(updated.name, 'Renamed MacBook');

      await repo.setDeviceBlocked(mac, true);
      final blocked = (await repo.fetchDevices()).firstWhere((d) => d.key == mac);
      expect(blocked.blocked, isTrue);

      final decoders = await repo.fetchTvDecoders();
      expect(decoders, isNotEmpty);
      final zapped = await repo.zapTvChannel(decoders.first.key, 4, 'Canal+ UHD');
      expect(zapped.channelNumber, 4);

      final apiJson = await repo.executeRawApi('DeviceInfo', 'get', {});
      expect(apiJson, contains('Livebox W7'));
    });
  });

  group('Desktop UI end-to-end widget tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Login screen -> Demo Mode -> navigate all 11 desktop tabs cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController();
      await controller.initialize();

      await tester.pumpWidget(LiveboxMonitorApp(controller: controller));
      await tester.pumpAndSettle();

      // Login screen visible
      expect(find.text('Livebox Monitor'), findsOneWidget);
      expect(find.textContaining('Launch Interactive Demo Mode'), findsOneWidget);

      // Switch to French and back to English
      await controller.setLanguage(AppLanguage.fr);
      await tester.pumpAndSettle();
      expect(find.textContaining('Mode Démo Interactif'), findsOneWidget);

      await controller.setLanguage(AppLanguage.en);
      await tester.pumpAndSettle();

      // Launch Demo Mode
      await tester.tap(find.textContaining('Launch Interactive Demo Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Overview screen loaded
      expect(find.text('Livebox 7 W7'), findsAtLeastNWidgets(1));
      expect(find.text('WAN / Fiber Status'), findsOneWidget);

      // Navigate through every section in the sidebar
      final navTargets = [
        'Devices',
        'Traffic Graphs',
        'Events',
        'DHCP',
        'NAT / PAT',
        'Firewall',
        'Phone / VoIP',
        'Repeaters',
        'TV Decoders',
        'Actions & Tools',
      ];

      for (final label in navTargets) {
        final item = find.text(label).first;
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull, reason: 'No exception on $label screen');
      }

      // Clean disconnect stops polling timer cleanly
      await controller.disconnect();
      await tester.pump();
    });
  });
}
