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
  final detail = service.getDeviceDetail(decodedMac, hours: hours);
  if (detail == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Équipement introuvable: $decodedMac'},
    );
  }
  return Response.json(body: detail);
}
