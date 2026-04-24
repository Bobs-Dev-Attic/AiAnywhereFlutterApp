import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/server_config.dart';
import '../models/message.dart';
import 'log_service.dart';

enum ConnectionStatus { connected, connecting, disconnected, error }

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ApiException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${body != null ? '\n$body' : ''}';
}

/// ApiService handles all HTTP communication with AI backends.
/// Supports Ollama, llama.cpp, and LM Studio (OpenAI-compatible).
class ApiService {
  static const _uuid = Uuid();
  final LogService _log;

  ApiService(this._log);

  // ─── Connection Test ──────────────────────────────────────────────────────

  Future<ConnectionStatus> testConnection(
    ServerConfig config, {
    String? apiKey,
  }) async {
    _log.info('Testing connection to ${config.name}', tag: 'ApiService');
    try {
      final uri = _buildHealthUri(config);
      final response = await http
          .get(uri, headers: _buildHeaders(apiKey))
          .timeout(Duration(seconds: config.timeoutSeconds));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log.info('Connection OK: ${config.baseUrl}', tag: 'ApiService');
        return ConnectionStatus.connected;
      }
      _log.warning(
        'Connection returned ${response.statusCode}',
        tag: 'ApiService',
      );
      return ConnectionStatus.error;
    } on SocketException catch (e) {
      _log.error('Network error: $e', tag: 'ApiService');
      return ConnectionStatus.disconnected;
    } on TimeoutException {
      _log.warning('Connection timed out', tag: 'ApiService');
      return ConnectionStatus.error;
    } catch (e) {
      _log.error('Unexpected error: $e', tag: 'ApiService');
      return ConnectionStatus.error;
    }
  }

  Uri _buildHealthUri(ServerConfig config) {
    switch (config.serverType) {
      case ServerType.ollama:
        return Uri.parse('${config.baseUrl}/api/tags');
      case ServerType.llamaCpp:
        return Uri.parse('${config.baseUrl}/health');
      case ServerType.lmStudio:
        return Uri.parse('${config.baseUrl}/v1/models');
    }
  }

  // ─── Chat Completion (streaming) ─────────────────────────────────────────

  /// Sends [messages] and yields response chunks.
  Stream<String> sendMessageStream({
    required ServerConfig config,
    required List<Message> messages,
    String? apiKey,
  }) async* {
    _log.info(
      'Sending ${messages.length} messages to ${config.name}',
      tag: 'ApiService',
    );

    switch (config.serverType) {
      case ServerType.ollama:
        yield* _ollamaStream(config, messages, apiKey);
      case ServerType.llamaCpp:
        yield* _openAiStream(
          config,
          messages,
          apiKey,
          endpoint: '/v1/chat/completions',
        );
      case ServerType.lmStudio:
        yield* _openAiStream(
          config,
          messages,
          apiKey,
          endpoint: '/v1/chat/completions',
        );
    }
  }

  // ─── Ollama ───────────────────────────────────────────────────────────────

  Stream<String> _ollamaStream(
    ServerConfig config,
    List<Message> messages,
    String? apiKey,
  ) async* {
    final uri = Uri.parse('${config.baseUrl}/api/chat');
    final body = json.encode({
      'model': config.model.isNotEmpty ? config.model : 'llama3',
      'messages': messages.map((m) => m.toApiMap()).toList(),
      'stream': true,
      'options': {
        'temperature': config.temperature,
        'num_predict': config.maxTokens,
      },
    });

    yield* _streamRequest(uri, body, config, apiKey, _parseOllamaChunk);
  }

  String? _parseOllamaChunk(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final data = json.decode(line) as Map<String, dynamic>;
      final msg = data['message'] as Map<String, dynamic>?;
      if (msg != null) {
        return msg['content'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── OpenAI-compatible (LM Studio & llama.cpp) ───────────────────────────

  Stream<String> _openAiStream(
    ServerConfig config,
    List<Message> messages,
    String? apiKey, {
    required String endpoint,
  }) async* {
    final uri = Uri.parse('${config.baseUrl}$endpoint');
    final payload = <String, dynamic>{
      'model': config.model.isNotEmpty ? config.model : 'local-model',
      'messages': messages.map((m) => m.toApiMap()).toList(),
      'stream': true,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
    };

    final body = json.encode(payload);
    yield* _streamRequest(uri, body, config, apiKey, _parseOpenAiChunk);
  }

  String? _parseOpenAiChunk(String line) {
    if (!line.startsWith('data: ')) return null;
    final data = line.substring(6).trim();
    if (data == '[DONE]') return null;
    try {
      final decoded = json.decode(data) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;
      final delta =
          (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
      return delta?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Generic Streaming HTTP ───────────────────────────────────────────────

  Stream<String> _streamRequest(
    Uri uri,
    String body,
    ServerConfig config,
    String? apiKey,
    String? Function(String line) chunkParser,
  ) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(_buildHeaders(apiKey))
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      _log.debug('POST $uri', tag: 'ApiService');

      final streamedResponse = await client
          .send(request)
          .timeout(Duration(seconds: config.timeoutSeconds));

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        final errorBody =
            await streamedResponse.stream.bytesToString();
        throw ApiException(
          _statusCodeMessage(streamedResponse.statusCode),
          statusCode: streamedResponse.statusCode,
          body: errorBody,
        );
      }

      final buffer = StringBuffer();
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final text = chunkParser(chunk);
        if (text != null && text.isNotEmpty) {
          buffer.write(text);
          yield text;
        }
      }

      _log.info(
        'Stream complete (${buffer.length} chars)',
        tag: 'ApiService',
      );
    } on SocketException catch (e) {
      _log.error('Network error: $e', tag: 'ApiService');
      throw ApiException('Cannot reach server. Check your Tailscale VPN and server address.');
    } on TimeoutException {
      _log.warning('Request timed out', tag: 'ApiService');
      throw ApiException('Request timed out. The server may be busy or unreachable.');
    } on ApiException {
      rethrow;
    } catch (e) {
      _log.error('Stream error: $e', tag: 'ApiService');
      throw ApiException('An unexpected error occurred: $e');
    } finally {
      client.close();
    }
  }

  // ─── List Models ─────────────────────────────────────────────────────────

  Future<List<String>> listModels(
    ServerConfig config, {
    String? apiKey,
  }) async {
    _log.info('Fetching models from ${config.name}', tag: 'ApiService');
    try {
      switch (config.serverType) {
        case ServerType.ollama:
          return await _listOllamaModels(config, apiKey);
        case ServerType.llamaCpp:
        case ServerType.lmStudio:
          return await _listOpenAiModels(config, apiKey);
      }
    } catch (e) {
      _log.warning('Could not list models: $e', tag: 'ApiService');
      return [];
    }
  }

  Future<List<String>> _listOllamaModels(
    ServerConfig config,
    String? apiKey,
  ) async {
    final uri = Uri.parse('${config.baseUrl}/api/tags');
    final response = await http
        .get(uri, headers: _buildHeaders(apiKey))
        .timeout(Duration(seconds: config.timeoutSeconds));
    _checkResponse(response);
    final data = json.decode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>? ?? [];
    return models
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  Future<List<String>> _listOpenAiModels(
    ServerConfig config,
    String? apiKey,
  ) async {
    final uri = Uri.parse('${config.baseUrl}/v1/models');
    final response = await http
        .get(uri, headers: _buildHeaders(apiKey))
        .timeout(Duration(seconds: config.timeoutSeconds));
    _checkResponse(response);
    final data = json.decode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>? ?? [];
    return models
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Map<String, String> _buildHeaders(String? apiKey) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _statusCodeMessage(response.statusCode),
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  String _statusCodeMessage(int code) {
    switch (code) {
      case 401:
        return 'Unauthorized. Check your API key.';
      case 403:
        return 'Forbidden. You don\'t have access to this resource.';
      case 404:
        return 'Not found. Check the server URL and model name.';
      case 422:
        return 'Invalid request. Check your model and parameters.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      case 500:
        return 'Server error. The AI server encountered a problem.';
      case 503:
        return 'Service unavailable. The server may be loading a model.';
      default:
        return 'Request failed with status $code.';
    }
  }
}
