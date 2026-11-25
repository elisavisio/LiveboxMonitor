import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class LiveboxApiException implements Exception {
  final String message;
  LiveboxApiException(this.message);

  @override
  String toString() => message;
}

/// Pure Dart implementation of the Orange Livebox sysbus HTTP JSON-RPC session
/// (ported from LmSession.py).
///
/// Uses raw `Set-Cookie` / `Cookie` headers instead of `dart:io`'s `Cookie`
/// parser because Orange Livebox session cookies contain `/` in the cookie name
/// (e.g. `890c73a1/sessid=...`), which causes `Cookie.fromSetCookieValue` to
/// throw a `FormatException`.
class LiveboxSession {
  static const String appName = 'so_sdkut';
  static const Duration defaultTimeout = Duration(seconds: 6);

  final String baseUrl;
  final String sessionName;

  HttpClient? _client;
  // Raw cookie map: preserves Livebox cookie names containing '/' (e.g. '890c73a1/sessid')
  final Map<String, String> _rawCookies = {};
  String? _contextId;
  int _channelId = 0;
  String _user = '';
  String _password = '';

  final List<String> _debugLogs = [];
  String? _lastErrorDetail;

  LiveboxSession(String url, {this.sessionName = 'LiveboxMonitor'})
      : baseUrl = '${url.trim().replaceAll(RegExp(r'/+$'), '')}/';

  bool get isAuthenticated => _contextId != null && _client != null;
  List<String> get debugLogs => List.unmodifiable(_debugLogs);
  String? get lastErrorDetail => _lastErrorDetail;

  void _log(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = '[$ts] $message';
    _debugLogs.add(line);
    if (_debugLogs.length > 200) _debugLogs.removeAt(0);
    debugPrint('[LiveboxSession] $line');
  }

  HttpClient _createClient() {
    final c = HttpClient();
    c.connectionTimeout = defaultTimeout;
    // Livebox local HTTPS uses a self-signed certificate.
    c.badCertificateCallback = (cert, host, port) => true;
    return c;
  }

  Map<String, String> get _serviceHeaders => {
        'Accept': '*/*',
        'Authorization': 'X-Sah $_contextId',
        'Content-Type': 'application/x-sah-ws-4-call+json; charset=UTF-8',
        'X-Context': _contextId ?? '',
      };

  Map<String, String> get _eventHeaders => {
        'Accept': '*/*',
        'Authorization': 'X-Sah $_contextId',
        'Content-Type': 'application/x-sah-event-4-call+json; charset=UTF-8',
        'X-Context': _contextId ?? '',
      };

  /// Signs in to the Livebox.
  /// Returns `1` on success, `0` on bad credentials, `-1` on connectivity error.
  Future<int> signIn(String user, String password) async {
    await close();
    _debugLogs.clear();
    _lastErrorDetail = null;
    _user = user;
    _password = password;
    _client = _createClient();
    _rawCookies.clear();
    _channelId = 0;

    final wsUrl = '${baseUrl}ws';
    _log('Starting signIn -> POST $wsUrl (user="$user", password=***)');

    final authBody = jsonEncode({
      'service': 'sah.Device.Information',
      'method': 'createContext',
      'parameters': {
        'applicationName': appName,
        'username': user,
        'password': password,
      },
    });

    try {
      final resp = await _postRaw(
        wsUrl,
        body: authBody,
        headers: const {
          'Accept': '*/*',
          'Authorization': 'X-Sah-Login',
          'Content-Type': 'application/x-sah-ws-4-call+json',
        },
        timeout: defaultTimeout,
        logStep: 'createContext',
      );

      final snippet = resp.length > 260 ? '${resp.substring(0, 260)}...' : resp;
      _log('createContext body: $snippet');

      final decoded = jsonDecode(resp);
      if (decoded is! Map<String, dynamic>) {
        _lastErrorDetail = 'Unexpected non-object JSON from createContext: $snippet';
        _log(_lastErrorDetail!);
        return 0;
      }

      // Livebox returns {"status":0,"data":{"contextID":"..."}} (or under result)
      final data = decoded['data'] ??
          (decoded['result'] is Map ? (decoded['result'] as Map)['data'] : null);
      if (data is! Map<String, dynamic> || data['contextID'] == null) {
        _lastErrorDetail = 'No contextID in createContext reply (bad credentials?): $snippet';
        _log(_lastErrorDetail!);
        return 0;
      }

      _contextId = data['contextID'].toString();
      _log('Authenticated contextID received (${_contextId!.length} chars). Cookies: ${_rawCookies.keys.join(", ")}');

      // Verify session via Time:getTime
      final checkResp = await _postRaw(
        wsUrl,
        body: '{"service":"Time","method":"getTime","parameters":{}}',
        headers: _serviceHeaders,
        timeout: defaultTimeout,
        logStep: 'Time:getTime',
      );
      final checkSnippet = checkResp.length > 200 ? '${checkResp.substring(0, 200)}...' : checkResp;
      _log('Time:getTime body: $checkSnippet');

      final checkJson = jsonDecode(checkResp);
      final ok = checkJson is Map &&
          (checkJson['status'] == true ||
              (checkJson['result'] is Map &&
                  (checkJson['result'] as Map)['status'] == true));
      if (ok) {
        _log('Session verified successfully!');
        return 1;
      }

      _lastErrorDetail = 'Time:getTime check did not return status=true: $checkSnippet';
      _log(_lastErrorDetail!);
      await close();
      return 0;
    } on SocketException catch (e) {
      _lastErrorDetail = 'SocketException: ${e.message} (OS error: ${e.osError})';
      _log(_lastErrorDetail!);
      await close();
      return -1;
    } on TimeoutException catch (e) {
      _lastErrorDetail = 'TimeoutException after ${defaultTimeout.inSeconds}s: $e';
      _log(_lastErrorDetail!);
      await close();
      return -1;
    } on HttpException catch (e) {
      _lastErrorDetail = 'HttpException: ${e.message}';
      _log(_lastErrorDetail!);
      await close();
      return -1;
    } on FormatException catch (e) {
      _lastErrorDetail = 'FormatException while parsing Livebox response: $e';
      _log(_lastErrorDetail!);
      await close();
      return -1;
    } catch (e, st) {
      _lastErrorDetail = '${e.runtimeType}: $e';
      _log('Unexpected signIn error: $e\n$st');
      await close();
      return -1;
    }
  }

  /// Releases the session context and closes the HTTP client.
  Future<void> close() async {
    if (_client != null && _contextId != null) {
      try {
        await _postRaw(
          '${baseUrl}ws',
          body: jsonEncode({
            'service': 'sah.Device.Information',
            'method': 'releaseContext',
            'parameters': {'applicationName': appName},
          }),
          headers: _serviceHeaders,
          timeout: const Duration(seconds: 2),
        );
      } catch (_) {}
    }
    _client?.close(force: true);
    _client = null;
    _contextId = null;
    _rawCookies.clear();
    _channelId = 0;
  }

  /// Sends a Livebox sysbus service call (`POST /ws` or `GET /sysbus/...`).
  Future<dynamic> request(
    String service, {
    String? method,
    dynamic args,
    bool get = false,
    Duration timeout = defaultTimeout,
  }) async {
    if (!isAuthenticated) {
      if (_user.isNotEmpty) {
        final ok = await signIn(_user, _password);
        if (ok <= 0) {
          throw LiveboxApiException('Not authenticated');
        }
      } else {
        throw LiveboxApiException('No active session');
      }
    }

    String raw;
    if (get) {
      var path = 'sysbus/${service.replaceAll('.', '/')}';
      if (method != null && method.isNotEmpty) {
        path += ':$method';
      }
      final depth = args ?? -1;
      path += '?_restDepth=$depth';
      raw = await _getRaw('$baseUrl$path', headers: _serviceHeaders, timeout: timeout);
      raw = raw.replaceAll('[,]', '[]');
      if (raw.startsWith(',"errors":')) {
        raw = '{${raw.substring(1)}}';
      } else if (raw.contains('}{')) {
        raw = '[${raw.replaceAll('}{', '},{')}]';
      }
    } else {
      final payload = <String, dynamic>{
        'service': service.startsWith('sysbus.') ? service : 'sysbus.$service',
        'method': ?method,
        'parameters': args ?? <String, dynamic>{},
      };
      raw = await _postRaw(
        '${baseUrl}ws',
        body: jsonEncode(payload),
        headers: _serviceHeaders,
        timeout: timeout,
      );
    }

    final decoded = jsonDecode(raw);
    if (!get && decoded is Map<String, dynamic> && decoded.containsKey('result')) {
      return decoded['result'];
    }
    return decoded;
  }

  /// Calls a sysbus service and returns the full reply map (must have `status`).
  Future<Map<String, dynamic>> callRaw(
    String service, {
    String? method,
    dynamic args,
    Duration timeout = defaultTimeout,
  }) async {
    final res = await request(service, method: method, args: args, timeout: timeout);
    if (res is Map<String, dynamic>) {
      final err = _extractErrors(res);
      if (err != null) {
        throw LiveboxApiException('$service:${method ?? ''} -> $err');
      }
      if (res.containsKey('status')) return res;
    }
    throw LiveboxApiException('$service:${method ?? ''} returned invalid response');
  }

  /// Calls a sysbus service and returns its `status` value (may be null/false).
  Future<dynamic> callNoCheck(
    String service, {
    String? method,
    dynamic args,
    Duration timeout = defaultTimeout,
  }) async {
    final raw = await callRaw(service, method: method, args: args, timeout: timeout);
    return raw['status'];
  }

  /// Calls a sysbus service and asserts `status` is truthy.
  Future<dynamic> call(
    String service, {
    String? method,
    dynamic args,
    Duration timeout = defaultTimeout,
  }) async {
    final status = await callNoCheck(service, method: method, args: args, timeout: timeout);
    if (status == null || status == false || status == '' || status == 0) {
      throw LiveboxApiException('$service:${method ?? ''} failed');
    }
    return status;
  }

  /// Polls the Livebox event channel (`POST /ws` with event content type).
  Future<Map<String, dynamic>?> eventRequest(
    List<String> events, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!isAuthenticated) return null;
    final payload = <String, dynamic>{
      'events': events,
      if (_channelId != 0) 'channelid': _channelId,
    };
    try {
      var raw = await _postRaw(
        '${baseUrl}ws',
        body: jsonEncode(payload),
        headers: _eventHeaders,
        timeout: timeout,
      );
      if (raw.endsWith('null')) {
        raw = raw.substring(0, raw.length - 4);
      }
      if (raw.trim().isEmpty) return null;
      var decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['result'] is Map<String, dynamic>) {
          decoded = decoded['result'] as Map<String, dynamic>;
        }
        final ch = decoded['channelid'];
        if (ch is int) _channelId = ch;
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String? _extractErrors(Map<String, dynamic> reply) {
    final errors = reply['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors
          .whereType<Map>()
          .map((e) => '${e['description'] ?? ''} ${e['info'] ?? ''}'.trim())
          .where((s) => s.isNotEmpty)
          .join('; ');
    }
    if (reply['error'] != null) {
      return '[${reply['error']}] ${reply['description'] ?? ''} ${reply['info'] ?? ''}'.trim();
    }
    return null;
  }

  Future<String> _postRaw(
    String url, {
    required String body,
    required Map<String, String> headers,
    required Duration timeout,
    String? logStep,
  }) async {
    final client = _client ?? _createClient();
    final uri = Uri.parse(url);
    final req = await client.postUrl(uri).timeout(timeout);
    headers.forEach((k, v) => req.headers.set(k, v));
    _attachCookies(req);
    final bytes = utf8.encode(body);
    req.headers.contentLength = bytes.length;
    req.add(bytes);
    final resp = await req.close().timeout(timeout);
    _storeRawCookies(resp.headers[HttpHeaders.setCookieHeader], logStep: logStep);
    if (logStep != null) {
      _log('$logStep HTTP ${resp.statusCode} ${resp.reasonPhrase} (cookies=${_rawCookies.length})');
    }
    final respBytes = await resp
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk))
        .timeout(timeout);
    return utf8.decode(respBytes, allowMalformed: true);
  }

  Future<String> _getRaw(
    String url, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final client = _client ?? _createClient();
    final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
    headers.forEach((k, v) => req.headers.set(k, v));
    _attachCookies(req);
    final resp = await req.close().timeout(timeout);
    _storeRawCookies(resp.headers[HttpHeaders.setCookieHeader]);
    final respBytes = await resp
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk))
        .timeout(timeout);
    return utf8.decode(respBytes, allowMalformed: true);
  }

  void _attachCookies(HttpClientRequest req) {
    if (_rawCookies.isNotEmpty) {
      final headerVal =
          _rawCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      req.headers.set(HttpHeaders.cookieHeader, headerVal);
    }
  }

  void _storeRawCookies(List<String>? setCookieHeaders, {String? logStep}) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return;
    for (final header in setCookieHeaders) {
      final firstPart = header.split(';').first.trim();
      final eqIdx = firstPart.indexOf('=');
      if (eqIdx <= 0) continue;
      final name = firstPart.substring(0, eqIdx).trim();
      final value = firstPart.substring(eqIdx + 1).trim();
      if (name.isNotEmpty) {
        _rawCookies[name] = value;
        if (logStep != null) {
          _log('$logStep stored cookie "$name" (${value.length} chars)');
        }
      }
    }
  }
}
