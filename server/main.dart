import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';
import 'package:livebox_monitor_server/storage/monitor_database.dart';
import 'package:livebox_monitor_server/storage/secret_vault.dart';
import 'package:livebox_monitor_server/utils/base_path.dart';

LiveboxMonitorService? _service;
BasePathConfig _basePathConfig = BasePathConfig.fromRaw(null);

String _resolveDataDir() {
  final envDir = Platform.environment['DATA_DIR']?.trim();
  if (envDir != null && envDir.isNotEmpty) return envDir;
  if (Directory('/data').existsSync()) return '/data';
  return '${Directory.current.path}/data';
}

Future<void> init(InternetAddress ip, int port) async {
  final dataDir = _resolveDataDir();
  _basePathConfig = BasePathConfig.fromEnvironment();
  stdout.writeln('[LiveboxMonitorServer] Data directory: $dataDir');
  if (!_basePathConfig.isRoot) {
    stdout.writeln(
      '[LiveboxMonitorServer] Base path (ProxyPass): ${_basePathConfig.basePath}',
    );
  }

  final vault = SecretVault(dataDir: dataDir);
  final db = MonitorDatabase.open(dataDir: dataDir);
  final dashboardUrl = Platform.environment['DASHBOARD_URL']?.trim();

  final service = LiveboxMonitorService(
    db: db,
    vault: vault,
    dashboardUrl: (dashboardUrl != null && dashboardUrl.isNotEmpty)
        ? dashboardUrl
        : null,
  );
  await service.start();
  _service = service;

  // Graceful shutdown on container stop
  ProcessSignal.sigterm.watch().listen((_) async {
    stdout.writeln('[LiveboxMonitorServer] SIGTERM received, shutting down...');
    await _service?.dispose();
    exit(0);
  });
}

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  if (_service == null) {
    await init(ip, port);
  }
  final wrapped = handler
      .use(provider<LiveboxMonitorService>((_) => _service!))
      .use(provider<BasePathConfig>((_) => _basePathConfig))
      .use(_basePathConfig.stripPrefixMiddleware());
  return serve(wrapped, ip, port);
}
