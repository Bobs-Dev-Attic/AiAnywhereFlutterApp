import 'package:flutter/foundation.dart';

import '../models/server_config.dart';
import 'log_service.dart';

/// Privacy-safe, opt-in telemetry hook.
///
/// Current implementation is local-only and disabled by default.
/// It intentionally excludes prompt/response content, API keys, and hostnames.
class TelemetryService extends ChangeNotifier {
  final LogService _log;
  bool _enabled = false;

  TelemetryService(this._log);

  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    _log.info('Telemetry ${value ? 'enabled' : 'disabled'}', tag: 'Telemetry');
  }

  void recordStreamResult({
    required ServerType serverType,
    required int latencyMs,
    required bool success,
    required bool canceled,
  }) {
    if (!_enabled) return;
    _log.info(
      'telemetry stream_result type=${serverType.name} latency_ms=$latencyMs success=$success canceled=$canceled',
      tag: 'Telemetry',
    );
  }
}
