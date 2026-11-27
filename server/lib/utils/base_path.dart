import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Handles optional reverse-proxy base path (e.g. `BASE_PATH=/livebox`).
///
/// Works seamlessly with BOTH reverse-proxy styles:
/// 1. ProxyPass keeping the prefix (`/livebox/api/devices` -> stripped internally)
/// 2. ProxyPass stripping the prefix (`/api/devices` -> passed straight through)
class BasePathConfig {
  /// Normalized base path: either `""` (root) or `"/prefix"` (no trailing slash).
  final String basePath;

  const BasePathConfig._(this.basePath);

  factory BasePathConfig.fromRaw(String? raw) =>
      BasePathConfig._(normalize(raw));

  factory BasePathConfig.fromEnvironment() =>
      BasePathConfig.fromRaw(Platform.environment['BASE_PATH']);

  bool get isRoot => basePath.isEmpty;

  /// Leading-slash-free path segment, e.g. `"livebox"` or `"tools/livebox"`.
  String get prefixSegment =>
      basePath.startsWith('/') ? basePath.substring(1) : basePath;

  /// Normalizes any user input (`"livebox"`, `"/livebox/"`, `"/"`, `""`) to
  /// `""` (root) or `"/livebox"` (leading slash, no trailing slash).
  static String normalize(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    final cleaned = trimmed
        .replaceAll(RegExp(r'/+'), '/')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) return '';
    return '/$cleaned';
  }

  /// Shelf middleware that strips [basePath] from incoming requests when
  /// present, while still allowing unprefixed requests (stripped ProxyPass or
  /// internal Docker `/api/health` checks) to pass through unchanged.
  shelf.Middleware buildShelfMiddleware() {
    if (isRoot) {
      return (shelf.Handler inner) => inner;
    }
    final seg = prefixSegment;
    return (shelf.Handler inner) {
      return (shelf.Request request) {
        final path = request.url.path;
        if (path == seg || path.startsWith('$seg/')) {
          final rewritten = path == seg
              ? _stripExactPrefix(request, seg)
              : request.change(path: seg);
          return inner(rewritten);
        }
        return inner(request);
      };
    };
  }

  /// Dart Frog middleware wrapper around [buildShelfMiddleware].
  Middleware stripPrefixMiddleware() =>
      isRoot ? (handler) => handler : fromShelfMiddleware(buildShelfMiddleware());

  static shelf.Request _stripExactPrefix(shelf.Request request, String seg) {
    final baseUri = request.requestedUri;
    final withSlash = baseUri.replace(path: '${baseUri.path}/');
    final clone = shelf.Request(
      request.method,
      withSlash,
      protocolVersion: request.protocolVersion,
      headers: request.headersAll,
      body: request.read(),
      context: request.context,
    );
    return clone.change(path: seg);
  }

  /// Injects `window.__LBM_BASE_PATH__` and prefixes root-relative asset URLs
  /// inside `public/index.html` so CSS/JS/favicons load under [basePath].
  String rewriteIndexHtml(String html) {
    final baseJson = jsonEncode(basePath);
    final injectScript = '<script>window.__LBM_BASE_PATH__=$baseJson;</script>';

    var out = html.contains('</head>')
        ? html.replaceFirst('</head>', '  $injectScript\n</head>')
        : '$injectScript\n$html';

    if (!isRoot) {
      for (final asset in const [
        '/styles.css',
        '/app.js',
        '/favicon.png',
        '/favicon.ico',
        '/apple-touch-icon.png',
      ]) {
        out = out
            .replaceAll('href="$asset"', 'href="$basePath$asset"')
            .replaceAll('src="$asset"', 'src="$basePath$asset"');
      }
    }
    return out;
  }
}
