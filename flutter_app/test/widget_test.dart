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

    testWidgets('iPad Portrait (820x1180) renders all 11 tabs and device inspector sheet cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController();
      await controller.initialize();
      await tester.pumpWidget(LiveboxMonitorApp(controller: controller));
      await tester.pumpAndSettle();

      // Launch Demo Mode
      await tester.tap(find.textContaining('Launch Interactive Demo Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Sidebar auto-collapses to compact rail on iPad Portrait -> navigate via Tooltip/Icons
      final navIcons = [
        Icons.devices_rounded,
        Icons.show_chart_rounded,
        Icons.notifications_active_outlined,
        Icons.dns_outlined,
        Icons.alt_route_rounded,
        Icons.shield_outlined,
        Icons.phone_in_talk_outlined,
        Icons.wifi_tethering_rounded,
        Icons.tv_rounded,
        Icons.tune_rounded,
      ];

      for (final icon in navIcons) {
        final item = find.byIcon(icon).first;
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull, reason: 'No exception on iPad Portrait tab $icon');
      }

      // Tap back to Devices and open the modal Device Inspector bottom sheet
      await tester.tap(find.byIcon(Icons.devices_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('MacBook Pro M4 Max').first);
      await tester.pumpAndSettle();
      expect(find.text('Wake-on-LAN'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await controller.disconnect();
      await tester.pump();
    });

    testWidgets('iPad Split View (640x1024) uses Drawer navigation with zero overflows',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(640, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController();
      await controller.initialize();
      await tester.pumpWidget(LiveboxMonitorApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Launch Interactive Demo Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Hamburger menu icon opens Drawer in Split View
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.text('TV Decoders'), findsOneWidget);
      await tester.tap(find.text('TV Decoders'));
      await tester.pumpAndSettle();
      expect(find.text('ORANGE TV'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await controller.disconnect();
      await tester.pump();
    });

    testWidgets('Devices tab defaults to Active (with IP) and supports Name/IP/ID/Bandwidth sort',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController();
      await controller.initialize();
      await tester.pumpWidget(LiveboxMonitorApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Launch Interactive Demo Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Devices').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Active is selected by default -> offline devices (Epson EcoTank Printer) are hidden
      expect(find.text('Epson EcoTank Printer'), findsNothing);
      expect(find.text('Garden IP Camera'), findsAtLeastNWidgets(1));

      // Sort selector defaults to Name; switch to Bandwidth -> highest consumer (Synology NAS) jumps to top!
      expect(find.text('Sort: Name'), findsOneWidget);
      await tester.tap(find.text('Sort: Name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: Bandwidth').last);
      await tester.pumpAndSettle();
      expect(find.text('Sort: Bandwidth'), findsOneWidget);
      expect(find.text('Synology DS923+ NAS'), findsAtLeastNWidgets(1));

      // Switch to Sort: IP and Sort: ID (MAC)
      await tester.tap(find.text('Sort: Bandwidth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: IP').last);
      await tester.pumpAndSettle();
      expect(find.text('Sort: IP'), findsOneWidget);

      await tester.tap(find.text('Sort: IP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: ID (MAC)').last);
      await tester.pumpAndSettle();
      expect(find.text('Sort: ID (MAC)'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await controller.disconnect();
      await tester.pump();
    });
  });
}
