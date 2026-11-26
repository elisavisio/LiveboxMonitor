import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();
  final limit =
      (int.tryParse(context.request.uri.queryParameters['limit'] ?? '') ?? 150)
          .clamp(1, 500);
  final mac = context.request.uri.queryParameters['mac'];
  return Response.json(
    body: {
      'events': service.listEventsJson(limit: limit, mac: mac),
    },
  );
}
