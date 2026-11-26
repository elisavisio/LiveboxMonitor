import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Response onRequest(RequestContext context) {
  final service = context.read<LiveboxMonitorService>();
  return Response.json(
    body: {
      'status': 'ok',
      'version': LiveboxMonitorService.appVersion,
      'connected': service.isConnected,
      'demoMode': service.isDemoMode,
      'readOnlyEnforced': true,
      'message': service.statusMessage,
    },
  );
}
