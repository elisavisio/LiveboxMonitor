import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/models/server_models.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Future<Response> onRequest(RequestContext context, String mac) async {
  if (context.request.method != HttpMethod.patch &&
      context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();
  final decodedMac = Uri.decodeComponent(mac);
  final body = await context.request.json();
  if (body is! Map<String, dynamic>) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Corps JSON invalide'},
    );
  }

  final rawTrust = body['trust']?.toString().toLowerCase();
  if (rawTrust != 'known' && rawTrust != 'unknown') {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Le champ trust doit être "known" ou "unknown"'},
    );
  }

  final note = body.containsKey('note') ? body['note']?.toString() : null;
  final updated = service.tagDevice(
    decodedMac,
    DeviceTrust.fromString(rawTrust),
    note: note,
  );
  if (updated == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Équipement introuvable: $decodedMac'},
    );
  }
  return Response.json(body: {'device': updated.toJson()});
}
