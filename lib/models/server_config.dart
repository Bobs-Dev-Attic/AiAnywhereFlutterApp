import 'dart:convert';
import 'dart:io';

enum ServerType { ollama, llamaCpp, lmStudio }

extension ServerTypeExtension on ServerType {
  String get displayName {
    switch (this) {
      case ServerType.ollama:
        return 'Ollama';
      case ServerType.llamaCpp:
        return 'llama.cpp';
      case ServerType.lmStudio:
        return 'LM Studio';
    }
  }

  String get defaultPort {
    switch (this) {
      case ServerType.ollama:
        return '11434';
      case ServerType.llamaCpp:
        return '8080';
      case ServerType.lmStudio:
        return '1234';
    }
  }

  String get defaultModel {
    switch (this) {
      case ServerType.ollama:
        return 'llama3';
      case ServerType.llamaCpp:
        return '';
      case ServerType.lmStudio:
        return 'local-model';
    }
  }
}



class ServerValidation {
  static const int minPort = 1;
  static const int maxPort = 65535;
  static const int minTimeoutSeconds = 5;
  static const int maxTimeoutSeconds = 300;
  static const int minModelLength = 1;
  static const int maxModelLength = 128;

  static String? validatePort(String value) {
    final port = int.tryParse(value.trim());
    if (port == null) return 'Must be a number';
    if (port < minPort || port > maxPort) {
      return 'Port must be $minPort-$maxPort';
    }
    return null;
  }

  static String? validateTimeoutSeconds(int value) {
    if (value < minTimeoutSeconds || value > maxTimeoutSeconds) {
      return 'Timeout must be $minTimeoutSeconds-$maxTimeoutSeconds seconds';
    }
    return null;
  }

  static String? validateModelId(String value) {
    final model = value.trim();
    if (model.isEmpty) return 'Model is required';
    if (model.length < minModelLength || model.length > maxModelLength) {
      return 'Model id must be $minModelLength-$maxModelLength chars';
    }
    final allowed = RegExp(r'^[a-zA-Z0-9._:-]+$');
    if (!allowed.hasMatch(model)) {
      return 'Use letters, numbers, dot, underscore, colon, hyphen';
    }
    return null;
  }
}

class ServerConfig {
  final String id;
  final String name;
  final ServerType serverType;
  final String host;
  final String port;
  final String model;
  final bool useTailscale;
  final bool useHttps;
  final int timeoutSeconds;
  final int maxTokens;
  final double temperature;
  final String systemPrompt;
  final bool isActive;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.serverType,
    required this.host,
    required this.port,
    this.model = '',
    this.useTailscale = false,
    this.useHttps = false,
    this.timeoutSeconds = 30,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.systemPrompt = 'You are a helpful assistant.',
    this.isActive = false,
  });

  String get baseUrl {
    final scheme = useHttps ? 'https' : 'http';
    return '$scheme://$host:$port';
  }

  ServerConfig copyWith({
    String? id,
    String? name,
    ServerType? serverType,
    String? host,
    String? port,
    String? model,
    bool? useTailscale,
    bool? useHttps,
    int? timeoutSeconds,
    int? maxTokens,
    double? temperature,
    String? systemPrompt,
    bool? isActive,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverType: serverType ?? this.serverType,
      host: host ?? this.host,
      port: port ?? this.port,
      model: model ?? this.model,
      useTailscale: useTailscale ?? this.useTailscale,
      useHttps: useHttps ?? this.useHttps,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverType': serverType.index,
        'host': host,
        'port': port,
        'model': model,
        'useTailscale': useTailscale,
        'useHttps': useHttps,
        'timeoutSeconds': timeoutSeconds,
        'maxTokens': maxTokens,
        'temperature': temperature,
        'systemPrompt': systemPrompt,
        'isActive': isActive,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        serverType: ServerType.values[json['serverType'] as int],
        host: json['host'] as String,
        port: json['port'] as String,
        model: json['model'] as String? ?? '',
        useTailscale: json['useTailscale'] as bool? ?? false,
        useHttps: json['useHttps'] as bool? ?? false,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 30,
        maxTokens: json['maxTokens'] as int? ?? 2048,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        systemPrompt:
            json['systemPrompt'] as String? ?? 'You are a helpful assistant.',
        isActive: json['isActive'] as bool? ?? false,
      );

  static ServerConfig defaultOllama() => ServerConfig(
        id: 'default_ollama',
        name: 'Home Ollama',
        serverType: ServerType.ollama,
        host: '100.64.0.1',
        port: '11434',
        model: 'llama3',
        useTailscale: true,
      );

  static String? validateHost(String value) {
    final host = value.trim();
    if (host.isEmpty) return 'Host is required';
    if (host.contains('://') || host.contains('/') || host.contains('?')) {
      return 'Enter hostname/IP only (no scheme or path)';
    }
    final lowered = host.toLowerCase();
    if (lowered == '0.0.0.0' || lowered == '::') {
      return 'Wildcard bind addresses are not allowed';
    }
    final ip = InternetAddress.tryParse(host);
    if (ip != null) return null;
    final hostRegex = RegExp(r'^[a-zA-Z0-9.-]+$');
    if (!hostRegex.hasMatch(host) || host.startsWith('.') || host.endsWith('.')) {
      return 'Invalid hostname';
    }
    return null;
  }
}

class ServerConfigList {
  final List<ServerConfig> configs;

  const ServerConfigList({this.configs = const []});

  factory ServerConfigList.fromJsonString(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return ServerConfigList(
      configs: list
          .map((e) => ServerConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() => json.encode(configs.map((c) => c.toJson()).toList());

  ServerConfig? get active =>
      configs.where((c) => c.isActive).firstOrNull;
}
