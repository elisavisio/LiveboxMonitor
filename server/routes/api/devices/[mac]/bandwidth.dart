import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Response onRequest(RequestContext context, String mac) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();
  final decodedMac = Uri.decodeComponent(mac);
  final hours =
      int.tryParse(context.request.uri.queryParameters['hours'] ?? '') ?? 24;
  final sinceMs = DateTime.now()
      .subtract(Duration(hours: hours.clamp(1, 168)))
      .millisecondsSinceEpoch;
  final points = service.db.getBandwidthHistory(decodedMac, sinceMs: sinceMs);
  return Response.json(
    body: {
      'mac': decodedMac.toUpperCase(),
      'hours': hours,
      'points': points.map((p) => p.toJson()).toList(),
    },
  );
}
