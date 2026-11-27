import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:livebox_monitor_server/utils/base_path.dart';
import 'package:path/path.dart' as p;

Future<Response> onRequest(RequestContext context) async {
  final basePathConfig = context.read<BasePathConfig>();
  final candidates = [
    p.join(Directory.current.path, 'public', 'index.html'),
    p.join(p.dirname(Platform.resolvedExecutable), 'public', 'index.html'),
    '/app/public/index.html',
  ];

  for (final filePath in candidates) {
    final file = File(filePath);
    if (file.existsSync()) {
      final rawHtml = await file.readAsString();
      final html = basePathConfig.rewriteIndexHtml(rawHtml);
      return Response(
        body: html,
        headers: const {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-cache',
        },
      );
    }
  }

  return Response(
    statusCode: 404,
    body: 'Livebox Monitor Web UI (public/index.html) introuvable.',
  );
}
