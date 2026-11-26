import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/models/server_models.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();

  SmtpConfig? override;
  try {
    final raw = await context.request.body();
    if (raw.trim().isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic> &&
          (parsed['host']?.toString().trim().isNotEmpty == true)) {
        final rawPass = parsed['password']?.toString();
        override = SmtpConfig(
          enabled: true,
          host: parsed['host'].toString().trim(),
          port: (parsed['port'] as num?)?.toInt() ?? 587,
          useSsl: parsed['useSsl'] == true,
          allowInsecure: parsed['allowInsecure'] == true,
          username: parsed['username']?.toString() ?? '',
          password: (rawPass != null && rawPass.isNotEmpty)
              ? rawPass
              : service.smtpConfig.password,
          fromAddress: parsed['fromAddress']?.toString() ?? '',
          toAddresses: parsed['toAddresses']?.toString() ?? '',
        );
      }
    }
  } catch (_) {}

  try {
    await service.sendTestEmail(override: override);
    return Response.json(
      body: {
        'ok': true,
        'message': 'Email de test envoyé avec succès !',
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {
        'ok': false,
        'error': e.toString(),
      },
    );
  }
}
