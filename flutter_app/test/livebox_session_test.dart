import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livebox_monitor/data/api/livebox_session.dart';
import 'package:livebox_monitor/data/api/real_livebox_repository.dart';
import 'package:livebox_monitor/data/models/models.dart';

void main() {
  late HttpServer mockLivebox;
  late String baseUrl;
  String? lastAuthHeader;
  String? lastContextHeader;
  bool cookieReceived = false;
  int stationPollCount = 0;

  setUp(() async {
    cookieReceived = false;
    stationPollCount = 0;
    mockLivebox = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${mockLivebox.address.address}:${mockLivebox.port}/';

    mockLivebox.listen((HttpRequest req) async {
      final body = await utf8.decoder.bind(req).join();
      lastAuthHeader = req.headers.value('authorization');
      lastContextHeader = req.headers.value('x-context');
      final rawCookieHeader = req.headers.value(HttpHeaders.cookieHeader) ?? '';
      if (rawCookieHeader.contains('890c73a1/sessid=cookie123')) {
        cookieReceived = true;
      }

      if (req.uri.path == '/ws') {
        final decoded = jsonDecode(body) as Map<String, dynamic>;

        // Event request check (tests trailing 'null' stripping too)
        if (decoded.containsKey('events')) {
          req.response
            ..headers.contentType = ContentType.json
            ..write(
              '{"channelid":7,"events":[{"data":{"handler":"Devices.Device.AA:BB:CC:DD:EE:FF","object":{"reason":"changed","Active":true}}}]}null',
            );
          await req.response.close();
          return;
        }

        final service = decoded['service']?.toString() ?? '';
        final method = decoded['method']?.toString() ?? '';

        if (service == 'sah.Device.Information' && method == 'createContext') {
          final params = decoded['parameters'] as Map<String, dynamic>;
          if (params['password'] == 'secret') {
            // Real Orange Livebox cookie names contain '/' (e.g. 890c73a1/sessid)
            req.response.headers.add(
              HttpHeaders.setCookieHeader,
              '890c73a1/sessid=cookie123; path=/; HttpOnly',
            );
            req.response.write(jsonEncode({
              'status': 0,
              'data': {'contextID': 'ctx_abc123'},
            }));
          } else {
            req.response.write(jsonEncode({'status': null, 'errors': []}));
          }
          await req.response.close();
          return;
        }

        if (service == 'Time' && method == 'getTime') {
          req.response.write(jsonEncode({
            'status': true,
            'data': {'time': '2026-11-25T10:00:00Z'},
          }));
          await req.response.close();
          return;
        }

        if (service == 'sysbus.DeviceInfo' && method == 'get') {
          req.response.write(jsonEncode({
            'result': {
              'status': {
                'Manufacturer': 'Sagemcom',
                'ProductClass': 'Livebox W7',
                'SerialNumber': 'SN123456',
                'HardwareVersion': 'HW1',
                'SoftwareVersion': 'SW5.24',
                'BaseMAC': 'aa:bb:cc:11:22:33',
                'UpTime': 3600,
                'ExternalIPAddress': '90.1.2.3',
              },
            },
          }));
          await req.response.close();
          return;
        }

        if (service == 'sysbus.Devices' && method == 'get') {
          req.response.write(jsonEncode({
            'result': {
              'status': [
                {
                  'Key': 'AA:BB:CC:DD:EE:FF',
                  'Name': 'Test Laptop',
                  'DeviceType': 'Laptop Linux',
                  'MACVendor': 'Lenovo',
                  'IPAddress': '192.168.1.42',
                  'Active': true,
                  'Tags': 'lan wifi ipv4',
                  'SignalStrength': -54,
                  'OperatingFrequencyBand': '5GHz',
                  'InterfaceName': 'vap5g0priv',
                },
              ],
            },
          }));
          await req.response.close();
          return;
        }

        if (service == 'sysbus.NeMo.Intf.vap5g0priv' && method == 'getStationStats') {
          stationPollCount++;
          req.response.write(jsonEncode({
            'result': {
              'status': [
                {
                  'MACAddress': 'AA:BB:CC:DD:EE:FF',
                  // Router TxBytes = device download (Rx); Router RxBytes = device upload (Tx)
                  'TxBytes': stationPollCount == 1 ? 1000000 : 1500000,
                  'RxBytes': stationPollCount == 1 ? 200000 : 300000,
                },
              ],
            },
          }));
          await req.response.close();
          return;
        }

        // Default benign empty status for auxiliary calls
        req.response.write(jsonEncode({'result': {'status': <String, dynamic>{}, 'data': <String, dynamic>{}}}));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await mockLivebox.close(force: true);
  });

  test('LiveboxSession authenticates with cookies & X-Context, handles calls, events & device bandwidth', () async {
    final session = LiveboxSession(baseUrl);

    // Bad password returns 0
    expect(await session.signIn('admin', 'wrong'), 0);

    // Valid password returns 1
    expect(await session.signIn('admin', 'secret'), 1);
    expect(session.isAuthenticated, isTrue);

    final repo = RealLiveboxRepository(session, label: 'Mock Livebox');

    // Fetch LiveboxInfo over real HTTP JSON-RPC
    final info = await repo.fetchLiveboxInfo();
    expect(info.modelName, 'Livebox W7');
    expect(info.macAddress, 'AA:BB:CC:11:22:33');
    expect(info.uptimeSeconds, 3600);
    expect(cookieReceived, isTrue);
    expect(lastAuthHeader, 'X-Sah ctx_abc123');
    expect(lastContextHeader, 'ctx_abc123');

    // Fetch Devices
    final devices = await repo.fetchDevices();
    expect(devices.length, 1);
    expect(devices.first.name, 'Test Laptop');
    expect(devices.first.rssi, -54);
    expect(devices.first.isWifi, isTrue);

    // Sample Wi-Fi station stats twice to verify non-zero swapped device bandwidth
    const wifiIntf = NetworkInterfaceInfo(
      key: 'vap5g0priv',
      name: 'Wi-Fi 5 GHz',
      type: 'wif',
      enabled: true,
      up: true,
      speedMbps: 2400,
      rxBytes: 0,
      txBytes: 0,
      rxBytesPerSec: 0,
      txBytesPerSec: 0,
    );
    await repo.sampleDeviceTraffic([wifiIntf]);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final devStats = await repo.sampleDeviceTraffic([wifiIntf]);
    final stat = devStats['AA:BB:CC:DD:EE:FF'];
    expect(stat, isNotNull);
    expect(stat!.rxBytes, 1500000);
    expect(stat.txBytes, 300000);
    expect(stat.rxBytesPerSec, greaterThan(0));
    expect(stat.txBytesPerSec, greaterThan(0));

    // Event polling strips trailing 'null' and maps device name
    final events = await repo.pollEvents();
    expect(events.length, 1);
    expect(events.first.deviceName, 'Test Laptop');
    expect(events.first.reason, 'changed');

    await repo.disconnect();
    expect(session.isAuthenticated, isFalse);
  });
}
