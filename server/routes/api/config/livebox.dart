import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final service = context.read<LiveboxMonitorService>();

  if (context.request.method == HttpMethod.get) {
    return Response.json(
      body: {
        'config': service.liveboxConfig.toRedactedJson(),
        'vault': {
          'encrypted': true,
          'algorithm': 'AES-256-GCM',
          'keySource': service.vault.keySource,
        },
        'readOnlyEnforced': true,
      },
    );
  }

  if (context.request.method == HttpMethod.post ||
      context.request.method == HttpMethod.put) {
    final body = await context.request.json();
    if (body is! Map<String, dynamic>) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Corps JSON invalide'},
      );
    }
    final result = await service.updateLiveboxConfig(
      url: body['url']?.toString() ?? service.liveboxConfig.url,
      username: body['username']?.toString() ?? service.liveboxConfig.username,
      password: body['password']?.toString(),
      demoMode: body['demoMode'] == true,
    );
    return Response.json(body: result);
  }

  return Response(statusCode: 405);
}
