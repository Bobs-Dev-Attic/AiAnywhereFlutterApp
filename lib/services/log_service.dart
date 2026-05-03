import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/log_entry.dart';
import 'storage_service.dart';

/// LogService provides structured, levelled logging.
/// Logs are stored persistently and viewable from the Logs screen.
class LogService extends ChangeNotifier {
  static const _uuid = Uuid();
  static const int _maxInMemory = 200;

  final StorageService _storage;
  final List<LogEntry> _entries = [];
  bool _initialized = false;

  LogService(this._storage);

  List<LogEntry> get entries => List.unmodifiable(_entries);

  Future<void> initialize() async {
    if (_initialized) return;
    final stored = await _storage.loadLogs();
    _entries.addAll(stored);
    _initialized = true;
    notifyListeners();
  }

  void debug(String message, {String? tag, String? details}) =>
      _log(LogLevel.debug, message, tag: tag, details: details);

  void info(String message, {String? tag, String? details}) =>
      _log(LogLevel.info, message, tag: tag, details: details);

  void warning(String message, {String? tag, String? details}) =>
      _log(LogLevel.warning, message, tag: tag, details: details);

  void error(String message, {String? tag, String? details}) =>
      _log(LogLevel.error, message, tag: tag, details: details);

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    String? details,
  }) {
    if (kReleaseMode && (level == LogLevel.debug || level == LogLevel.info)) {
      return;
    }
    final redactedMessage = _redact(message);
    final redactedDetails = details == null
        ? null
        : (kReleaseMode ? 'Details hidden in release build.' : _redact(details));
    final entry = LogEntry(
      id: _uuid.v4(),
      level: level,
      message: redactedMessage,
      tag: tag,
      details: redactedDetails,
      timestamp: DateTime.now(),
    );

    _entries.add(entry);
    if (_entries.length > _maxInMemory) {
      _entries.removeAt(0);
    }

    // Also output to the developer console in debug mode.
    if (kDebugMode) {
      developer.log(
        '${tag != null ? '[$tag] ' : ''}$redactedMessage',
        name: entry.level.label,
        level: _dartLogLevel(level),
        error: redactedDetails,
      );
    }

    notifyListeners();
    _persistAsync();
  }

  String _redact(String input) {
    var value = input;
    value = value.replaceAll(RegExp(r'(?i)(authorization:\s*bearer\s+)[^\s,]+'), r'$1[REDACTED]');
    value = value.replaceAll(RegExp(r'(?i)(api[_-]?key["\']?\s*[:=]\s*["\']?)[^"\',\s]+'), r'$1[REDACTED]');
    return value;
  }

  void _persistAsync() {
    unawaited(_storage.saveLogs(List.of(_entries)));
  }

  Future<void> clearLogs() async {
    _entries.clear();
    await _storage.clearLogs();
    notifyListeners();
  }

  int _dartLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
