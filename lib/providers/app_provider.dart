import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

import '../models/server_config.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

enum AppStatus { idle, loading, streaming, error }

class AppProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  final StorageService _storage;
  final ApiService _api;
  final LogService _log;
  final TelemetryService _telemetry;

  AppStatus _status = AppStatus.idle;
  String? _errorMessage;
  bool _initialized = false;

  List<ServerConfig> _servers = [];
  ServerConfig? _activeServer;
  String? _activeApiKey;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  List<ChatSession> _sessions = [];
  ChatSession? _activeSession;
  bool _cancelRequested = false;
  DateTime _lastUiFlush = DateTime.fromMillisecondsSinceEpoch(0);

  AppProvider({
    required StorageService storage,
    required ApiService api,
    required LogService log,
    required TelemetryService telemetry,
  })  : _storage = storage,
        _api = api,
        _log = log,
        _telemetry = telemetry;

  // ─── Getters ──────────────────────────────────────────────────────────────
  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get initialized => _initialized;
  bool get isLoading => _status == AppStatus.loading;
  bool get isStreaming => _status == AppStatus.streaming;

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  ServerConfig? get activeServer => _activeServer;
  ConnectionStatus get connectionStatus => _connectionStatus;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession => _activeSession;
  List<Message> get messages => _activeSession?.messages ?? [];

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _log.info('Initializing AppProvider', tag: 'AppProvider');

    _servers = await _storage.loadServerConfigs();
    _sessions = await _storage.loadChatSessions();

    // Restore active server
    final storedServerId = _storage.activeServerId;
    if (storedServerId != null) {
      _activeServer = _servers.where((s) => s.id == storedServerId).firstOrNull;
    }
    // Fall back to first server
    _activeServer ??= _servers.firstOrNull;

    if (_activeServer != null) {
      _activeApiKey = await _storage.loadApiKey(_activeServer!.id);
    }

    // Restore active session
    final storedSessionId = _storage.activeSessionId;
    if (storedSessionId != null) {
      _activeSession =
          _sessions.where((s) => s.id == storedSessionId).firstOrNull;
    }

    _initialized = true;
    notifyListeners();

    // Check connection asynchronously after first paint
    if (_activeServer != null) {
      checkConnection();
    }
  }

  // ─── Server Management ────────────────────────────────────────────────────

  Future<void> addServer(ServerConfig config, {String? apiKey}) async {
    _log.info('Adding server: ${config.name}', tag: 'AppProvider');
    await _storage.addServerConfig(config);
    if (apiKey != null && apiKey.isNotEmpty) {
      await _storage.saveApiKey(config.id, apiKey);
    }
    _servers = await _storage.loadServerConfigs();

    if (_activeServer == null) {
      await setActiveServer(config.id);
    }

    notifyListeners();
  }

  Future<void> updateServer(ServerConfig config, {String? apiKey}) async {
    _log.info('Updating server: ${config.name}', tag: 'AppProvider');
    await _storage.updateServerConfig(config);
    if (apiKey != null) {
      await _storage.saveApiKey(config.id, apiKey);
    }
    _servers = await _storage.loadServerConfigs();

    if (_activeServer?.id == config.id) {
      _activeServer = config;
      _activeApiKey = await _storage.loadApiKey(config.id);
    }

    notifyListeners();
  }

  Future<void> deleteServer(String id) async {
    _log.info('Deleting server: $id', tag: 'AppProvider');
    await _storage.deleteServerConfig(id);
    _servers = await _storage.loadServerConfigs();

    if (_activeServer?.id == id) {
      _activeServer = _servers.firstOrNull;
      _activeApiKey = _activeServer != null
          ? await _storage.loadApiKey(_activeServer!.id)
          : null;
      _connectionStatus = ConnectionStatus.disconnected;
      await _storage.saveActiveServerId(_activeServer?.id);
    }

    notifyListeners();
  }

  Future<void> setActiveServer(String id) async {
    final server = _servers.where((s) => s.id == id).firstOrNull;
    if (server == null) return;

    _activeServer = server;
    _activeApiKey = await _storage.loadApiKey(id);
    await _storage.saveActiveServerId(id);
    _connectionStatus = ConnectionStatus.disconnected;
    notifyListeners();

    await checkConnection();
  }

  Future<String?> getApiKey(String serverId) =>
      _storage.loadApiKey(serverId);

  /// Exposed for screens that need to test connections or fetch models
  /// without going through a full server config save.
  Future<ConnectionStatus> testConnectionDirect(
    ServerConfig config, {
    String? apiKey,
  }) =>
      _api.testConnection(config, apiKey: apiKey);

  Future<List<String>> listModelsDirect(
    ServerConfig config, {
    String? apiKey,
  }) =>
      _api.listModels(config, apiKey: apiKey);

  // ─── Connection ───────────────────────────────────────────────────────────

  Future<void> checkConnection() async {
    if (_activeServer == null) return;
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    _connectionStatus = await _api.testConnection(
      _activeServer!,
      apiKey: _activeApiKey,
    );
    notifyListeners();
  }

  // ─── Session Management ───────────────────────────────────────────────────

  Future<ChatSession> newChat() async {
    if (_activeServer == null) {
      throw StateError('No active server selected.');
    }
    final session = await _storage.createChatSession(_activeServer!.id);
    _sessions = await _storage.loadChatSessions();
    _activeSession = session;
    await _storage.saveActiveSessionId(session.id);
    notifyListeners();
    return session;
  }

  Future<void> setActiveSession(String id) async {
    final session = _sessions.where((s) => s.id == id).firstOrNull;
    if (session == null) return;
    _activeSession = session;
    await _storage.saveActiveSessionId(id);
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _storage.deleteChatSession(id);
    _sessions = await _storage.loadChatSessions();
    if (_activeSession?.id == id) {
      _activeSession = _sessions.firstOrNull;
      await _storage.saveActiveSessionId(_activeSession?.id);
    }
    notifyListeners();
  }

  // ─── Messaging ────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (_activeServer == null) {
      _setError('No server configured. Please add a server in Settings.');
      return;
    }
    if (text.trim().isEmpty) return;

    // Ensure we have an active session
    if (_activeSession == null) {
      await newChat();
    }

    _clearError();

    // Build the user message
    final userMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // Add system prompt as first message if session is new
    final history = List<Message>.from(_activeSession!.messages);
    if (history.isEmpty && _activeServer!.systemPrompt.isNotEmpty) {
      history.add(Message(
        id: _uuid.v4(),
        role: MessageRole.system,
        content: _activeServer!.systemPrompt,
        timestamp: DateTime.now(),
      ));
    }
    history.add(userMessage);

    // Add placeholder for assistant response
    final assistantMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    history.add(assistantMessage);

    await _updateSessionMessages(history);
    _status = AppStatus.streaming;
    notifyListeners();

    final buffer = StringBuffer();

    final startedAt = DateTime.now();
    var completed = false;
    try {
      // Build messages to send (exclude the empty streaming placeholder)
      final toSend = history
          .where((m) => !m.isStreaming)
          .toList();

      await for (final chunk in _api.sendMessageStream(
        config: _activeServer!,
        messages: toSend,
        apiKey: _activeApiKey,
      )) {
        if (_cancelRequested) {
          throw const ApiException('Generation canceled.');
        }
        buffer.write(chunk);
        final updated = List<Message>.from(_activeSession!.messages);
        final idx = updated.indexWhere((m) => m.id == assistantMessage.id);
        if (idx >= 0) {
          updated[idx] = assistantMessage.copyWith(
            content: buffer.toString(),
            isStreaming: true,
          );
          _applyInMemorySessionMessages(updated);
          final now = DateTime.now();
          if (now.difference(_lastUiFlush).inMilliseconds >= 80) {
            _lastUiFlush = now;
            notifyListeners();
          }
        }
      }

      // Finalise the assistant message
      final finalHistory = List<Message>.from(_activeSession!.messages);
      final idx = finalHistory.indexWhere((m) => m.id == assistantMessage.id);
      if (idx >= 0) {
        finalHistory[idx] = assistantMessage.copyWith(
          content: buffer.toString(),
          isStreaming: false,
        );
        await _updateSessionMessages(finalHistory);
      }

      completed = true;

      // Auto-title the session from the first user message
      if (_activeSession!.title == 'New Chat') {
        final title = _generateTitle(text);
        await _updateSessionTitle(title);
      }
    } on ApiException catch (e) {
      _log.error(e.message, tag: 'AppProvider', details: e.body);
      // Mark assistant message as errored
      final errHistory = List<Message>.from(_activeSession!.messages);
      final idx = errHistory.indexWhere((m) => m.id == assistantMessage.id);
      if (idx >= 0) {
        errHistory[idx] = assistantMessage.copyWith(
          content: buffer.toString(),
          isStreaming: false,
          error: e.message,
        );
        await _updateSessionMessages(errHistory);
      }
      _setError(e.message);
    } catch (e) {
      _log.error('Unexpected error: $e', tag: 'AppProvider');
      _setError('Something went wrong. Please try again.');
    } finally {
      final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
      _telemetry.recordStreamResult(
        serverType: _activeServer!.serverType,
        latencyMs: latencyMs,
        success: completed && !_cancelRequested,
        canceled: _cancelRequested,
      );
      _status = AppStatus.idle;
      notifyListeners();
    }
  }

  void cancelActiveStream() {
    _cancelRequested = true;
    _log.info('Active stream cancellation requested', tag: 'AppProvider');
  }

  void _applyInMemorySessionMessages(List<Message> messages) {
    if (_activeSession == null) return;
    _activeSession = _activeSession!.copyWith(
      messages: messages,
      updatedAt: DateTime.now(),
    );
    final idx = _sessions.indexWhere((s) => s.id == _activeSession!.id);
    if (idx >= 0) {
      _sessions[idx] = _activeSession!;
    }
  }

  Future<void> _updateSessionMessages(
    List<Message> messages, {
    bool notify = false,
  }) async {
    if (_activeSession == null) return;
    _activeSession = _activeSession!.copyWith(
      messages: messages,
      updatedAt: DateTime.now(),
    );
    final idx = _sessions.indexWhere((s) => s.id == _activeSession!.id);
    if (idx >= 0) {
      _sessions[idx] = _activeSession!;
    }
    await _storage.updateChatSession(_activeSession!);
    if (notify) notifyListeners();
  }

  Future<void> _updateSessionTitle(String title) async {
    if (_activeSession == null) return;
    _activeSession = _activeSession!.copyWith(title: title);
    await _storage.updateChatSession(_activeSession!);
    final idx = _sessions.indexWhere((s) => s.id == _activeSession!.id);
    if (idx >= 0) {
      _sessions[idx] = _activeSession!;
    }
    notifyListeners();
  }

  String _generateTitle(String firstMessage) {
    const maxLen = 40;
    final clean = firstMessage.trim().replaceAll('\n', ' ');
    if (clean.length <= maxLen) return clean;
    return '${clean.substring(0, maxLen)}…';
  }

  // ─── Error Handling ───────────────────────────────────────────────────────

  void _setError(String message) {
    _errorMessage = message;
    _status = AppStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    if (_status == AppStatus.error) {
      _status = AppStatus.idle;
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
    if (isStreaming) {
      cancelActiveStream();
    }
    _cancelRequested = false;
