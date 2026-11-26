import 'dart:async';
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/services/livebox_monitor_service.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final service = context.read<LiveboxMonitorService>();

  late final StreamController<List<int>> controller;
  StreamSubscription<Map<String, dynamic>>? sub;
  Timer? pingTimer;

  void emit(String eventName, Object payload) {
    if (controller.isClosed) return;
    final frame = 'event: $eventName\ndata: ${jsonEncode(payload)}\n\n';
    controller.add(utf8.encode(frame));
  }

  controller = StreamController<List<int>>(
    onListen: () {
      controller.add(utf8.encode(': connected\n\n'));
      emit('overview', service.getOverview());

      sub = service.sseEvents.listen((ev) {
        final type = ev['type']?.toString() ?? 'message';
        final data = (ev['data'] as Object?) ?? <String, dynamic>{};
        emit(type, data);
      });

      pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!controller.isClosed) {
          controller.add(utf8.encode(': ping\n\n'));
        }
      });
    },
    onCancel: () async {
      pingTimer?.cancel();
      await sub?.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    },
  );

  return Response.stream(
    body: controller.stream,
    headers: const {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  );
}
