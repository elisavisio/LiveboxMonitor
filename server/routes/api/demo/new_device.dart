import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();
  if (!service.isDemoMode) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'La simulation de nouvel équipement est disponible uniquement en Mode Démo.',
      },
    );
  }
  final dev = await service.simulateNewDevice();
  return Response.json(
    body: {
      'ok': true,
      'device': dev.toJson(),
    },
  );
}
