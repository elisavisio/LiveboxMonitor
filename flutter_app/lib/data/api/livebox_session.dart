import 'package:flutter/foundation.dart';
import 'package:livebox_client/livebox_client.dart' as shared;

export 'package:livebox_client/livebox_client.dart'
    show LiveboxApiException, LiveboxLogCallback;

/// Flutter wrapper around the shared pure-Dart [shared.LiveboxSession]
/// that forwards session trace logs to Flutter's [debugPrint].
class LiveboxSession extends shared.LiveboxSession {
  static const Duration defaultTimeout = shared.LiveboxSession.defaultTimeout;

  LiveboxSession(super.url, {super.sessionName})
      : super(onLog: debugPrint);
}
