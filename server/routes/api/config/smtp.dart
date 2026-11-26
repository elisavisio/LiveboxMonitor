import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final service = context.read<LiveboxMonitorService>();

  if (context.request.method == HttpMethod.get) {
    return Response.json(
      body: {
        'config': service.smtpConfig.toRedactedJson(),
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
    final result = await service.updateSmtpConfig(
      enabled: body['enabled'] == true,
      host: body['host']?.toString() ?? '',
      port: (body['port'] as num?)?.toInt() ?? 587,
      useSsl: body['useSsl'] == true,
      allowInsecure: body['allowInsecure'] == true,
      username: body['username']?.toString() ?? '',
      password: body['password']?.toString(),
      fromAddress: body['fromAddress']?.toString() ?? '',
      toAddresses: body['toAddresses']?.toString() ?? '',
    );
    return Response.json(body: result);
  }

  return Response(statusCode: 405);
}
