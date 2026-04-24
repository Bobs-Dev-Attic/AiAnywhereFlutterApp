import 'dart:convert';

enum LogLevel { debug, info, warning, error }

extension LogLevelExtension on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

class LogEntry {
  final String id;
  final LogLevel level;
  final String message;
  final String? tag;
  final String? details;
  final DateTime timestamp;

  const LogEntry({
    required this.id,
    required this.level,
    required this.message,
    this.tag,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.index,
        'message': message,
        'tag': tag,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        level: LogLevel.values[json['level'] as int],
        message: json['message'] as String,
        tag: json['tag'] as String?,
        details: json['details'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  static List<LogEntry> listFromJson(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<LogEntry> entries) =>
      json.encode(entries.map((e) => e.toJson()).toList());
}
