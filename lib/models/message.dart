import 'dart:convert';

enum MessageRole { user, assistant, system }

extension MessageRoleExtension on MessageRole {
  String get value {
    switch (this) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }

  static MessageRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }
}

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? error;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.error,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get hasError => error != null;

  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? error,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.value,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isStreaming': isStreaming,
        'error': error,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: MessageRoleExtension.fromString(json['role'] as String),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isStreaming: json['isStreaming'] as bool? ?? false,
        error: json['error'] as String?,
      );

  Map<String, String> toApiMap() => {
        'role': role.value,
        'content': content,
      };
}

class ChatSession {
  final String id;
  final String title;
  final String serverId;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.serverId,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    String? serverId,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      serverId: serverId ?? this.serverId,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'serverId': serverId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        serverId: json['serverId'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String toJsonString() => json.encode(toJson());

  factory ChatSession.fromJsonString(String jsonString) =>
      ChatSession.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}
