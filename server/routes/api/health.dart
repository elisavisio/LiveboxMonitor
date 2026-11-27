import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';
import 'package:livebox_monitor_server/utils/base_path.dart';

Response onRequest(RequestContext context) {
  final service = context.read<LiveboxMonitorService>();
  final basePath = context.read<BasePathConfig>().basePath;
  return Response.json(
    body: {
      'status': 'ok',
      'version': LiveboxMonitorService.appVersion,
      'basePath': basePath,
      'connected': service.isConnected,
      'demoMode': service.isDemoMode,
      'readOnlyEnforced': true,
      'message': service.statusMessage,
    },
  );
}
