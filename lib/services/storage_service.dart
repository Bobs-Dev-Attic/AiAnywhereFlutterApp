import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/server_config.dart';
import '../models/message.dart';
import '../models/log_entry.dart';

/// Keys for stored values
class _Keys {
  static const serverConfigs = 'server_configs';
  static const activeServerId = 'active_server_id';
  static const chatSessions = 'chat_sessions_index';
  static const logEntries = 'log_entries';
  static const apiKeyPrefix = 'api_key_';
  static const activeSessionId = 'active_session_id';
}

/// StorageService manages persistent, encrypted, and regular storage.
/// API keys are stored in encrypted secure storage; other settings
/// use SharedPreferences.
class StorageService {
  static const _uuid = Uuid();

  late final FlutterSecureStorage _secureStorage;
  late final SharedPreferences _prefs;
  bool _initialized = false;

  StorageService();

  /// Must be called once before using any other method.
  Future<void> initialize() async {
    if (_initialized) return;
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    _secureStorage = const FlutterSecureStorage(
      aOptions: androidOptions,
    );
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  void _assertInitialized() {
    assert(_initialized, 'StorageService must be initialized before use.');
  }

  // ─── Server Configs ───────────────────────────────────────────────────────

  Future<List<ServerConfig>> loadServerConfigs() async {
    _assertInitialized();
    final raw = _prefs.getString(_Keys.serverConfigs);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => ServerConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveServerConfigs(List<ServerConfig> configs) async {
    _assertInitialized();
    await _prefs.setString(
      _Keys.serverConfigs,
      json.encode(configs.map((c) => c.toJson()).toList()),
    );
  }

  Future<ServerConfig> addServerConfig(ServerConfig config) async {
    final configs = await loadServerConfigs();
    configs.add(config);
    await saveServerConfigs(configs);
    return config;
  }

  Future<void> updateServerConfig(ServerConfig updated) async {
    final configs = await loadServerConfigs();
    final idx = configs.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      configs[idx] = updated;
      await saveServerConfigs(configs);
    }
  }

  Future<void> deleteServerConfig(String id) async {
    final configs = await loadServerConfigs();
    configs.removeWhere((c) => c.id == id);
    await saveServerConfigs(configs);
    await deleteApiKey(id);
  }

  // ─── API Keys (Encrypted) ─────────────────────────────────────────────────

  Future<void> saveApiKey(String serverId, String apiKey) async {
    _assertInitialized();
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: '${_Keys.apiKeyPrefix}$serverId');
    } else {
      await _secureStorage.write(
        key: '${_Keys.apiKeyPrefix}$serverId',
        value: apiKey,
      );
    }
  }

  Future<String?> loadApiKey(String serverId) async {
    _assertInitialized();
    try {
      return await _secureStorage.read(
          key: '${_Keys.apiKeyPrefix}$serverId');
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteApiKey(String serverId) async {
    _assertInitialized();
    await _secureStorage.delete(key: '${_Keys.apiKeyPrefix}$serverId');
  }

  // ─── Chat Sessions ────────────────────────────────────────────────────────

  Future<List<ChatSession>> loadChatSessions() async {
    _assertInitialized();
    final raw = _prefs.getString(_Keys.chatSessions);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatSessions(List<ChatSession> sessions) async {
    _assertInitialized();
    await _prefs.setString(
      _Keys.chatSessions,
      json.encode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<ChatSession> createChatSession(String serverId) async {
    final session = ChatSession(
      id: _uuid.v4(),
      title: 'New Chat',
      serverId: serverId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final sessions = await loadChatSessions();
    sessions.insert(0, session);
    await saveChatSessions(sessions);
    return session;
  }

  Future<void> updateChatSession(ChatSession updated) async {
    final sessions = await loadChatSessions();
    final idx = sessions.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      sessions[idx] = updated;
      await saveChatSessions(sessions);
    }
  }

  Future<void> deleteChatSession(String id) async {
    final sessions = await loadChatSessions();
    sessions.removeWhere((s) => s.id == id);
    await saveChatSessions(sessions);
    if (_prefs.getString(_Keys.activeSessionId) == id) {
      await _prefs.remove(_Keys.activeSessionId);
    }
  }

  // ─── Active Session/Server ────────────────────────────────────────────────

  Future<void> saveActiveSessionId(String? id) async {
    _assertInitialized();
    if (id == null) {
      await _prefs.remove(_Keys.activeSessionId);
    } else {
      await _prefs.setString(_Keys.activeSessionId, id);
    }
  }

  String? get activeSessionId => _prefs.getString(_Keys.activeSessionId);

  Future<void> saveActiveServerId(String? id) async {
    _assertInitialized();
    if (id == null) {
      await _prefs.remove(_Keys.activeServerId);
    } else {
      await _prefs.setString(_Keys.activeServerId, id);
    }
  }

  String? get activeServerId => _prefs.getString(_Keys.activeServerId);

  // ─── Logs ─────────────────────────────────────────────────────────────────

  Future<List<LogEntry>> loadLogs() async {
    _assertInitialized();
    final raw = _prefs.getString(_Keys.logEntries);
    if (raw == null) return [];
    try {
      return LogEntry.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLogs(List<LogEntry> logs) async {
    _assertInitialized();
    const maxLogs = 500;
    final trimmed = logs.length > maxLogs
        ? logs.sublist(logs.length - maxLogs)
        : logs;
    await _prefs.setString(_Keys.logEntries, LogEntry.listToJson(trimmed));
  }

  Future<void> clearLogs() async {
    _assertInitialized();
    await _prefs.remove(_Keys.logEntries);
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  static String generateId() => const Uuid().v4();

  @visibleForTesting
  Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}
