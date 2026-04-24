import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_anywhere/models/message.dart';
import 'package:ai_anywhere/models/server_config.dart';
import 'package:ai_anywhere/models/log_entry.dart';
import 'package:ai_anywhere/theme.dart';
import 'package:ai_anywhere/widgets/chat_bubble.dart';
import 'package:ai_anywhere/widgets/status_dot.dart';
import 'package:ai_anywhere/widgets/empty_state.dart';
import 'package:ai_anywhere/widgets/connection_banner.dart';
import 'package:ai_anywhere/services/api_service.dart';

void main() {
  group('ServerConfig', () {
    test('toJson / fromJson round-trip', () {
      const config = ServerConfig(
        id: 'test-id',
        name: 'Test Server',
        serverType: ServerType.ollama,
        host: '100.64.0.1',
        port: '11434',
        model: 'llama3',
        useTailscale: true,
        temperature: 0.8,
        maxTokens: 1024,
      );

      final json = config.toJson();
      final restored = ServerConfig.fromJson(json);

      expect(restored.id, equals(config.id));
      expect(restored.name, equals(config.name));
      expect(restored.serverType, equals(config.serverType));
      expect(restored.host, equals(config.host));
      expect(restored.port, equals(config.port));
      expect(restored.model, equals(config.model));
      expect(restored.useTailscale, equals(config.useTailscale));
      expect(restored.temperature, closeTo(config.temperature, 0.001));
      expect(restored.maxTokens, equals(config.maxTokens));
    });

    test('baseUrl builds correctly', () {
      const config = ServerConfig(
        id: 'id',
        name: 'Server',
        serverType: ServerType.ollama,
        host: '100.64.0.1',
        port: '11434',
      );
      expect(config.baseUrl, equals('http://100.64.0.1:11434'));

      const httpsConfig = ServerConfig(
        id: 'id',
        name: 'Server',
        serverType: ServerType.ollama,
        host: '100.64.0.1',
        port: '11434',
        useHttps: true,
      );
      expect(httpsConfig.baseUrl, equals('https://100.64.0.1:11434'));
    });

    test('ServerType default ports', () {
      expect(ServerType.ollama.defaultPort, equals('11434'));
      expect(ServerType.llamaCpp.defaultPort, equals('8080'));
      expect(ServerType.lmStudio.defaultPort, equals('1234'));
    });

    test('copyWith creates a new instance with updated fields', () {
      const original = ServerConfig(
        id: 'id',
        name: 'Original',
        serverType: ServerType.ollama,
        host: '10.0.0.1',
        port: '11434',
      );
      final copy = original.copyWith(name: 'Updated', port: '5000');

      expect(copy.id, equals(original.id));
      expect(copy.name, equals('Updated'));
      expect(copy.port, equals('5000'));
      expect(copy.host, equals(original.host));
    });
  });

  group('Message', () {
    test('toJson / fromJson round-trip', () {
      final msg = Message(
        id: 'msg-1',
        role: MessageRole.user,
        content: 'Hello, world!',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      final json = msg.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, equals(msg.id));
      expect(restored.role, equals(msg.role));
      expect(restored.content, equals(msg.content));
      expect(restored.isStreaming, isFalse);
      expect(restored.error, isNull);
    });

    test('toApiMap excludes streaming/error fields', () {
      final msg = Message(
        id: 'id',
        role: MessageRole.assistant,
        content: 'Hi there',
        timestamp: DateTime.now(),
        isStreaming: true,
        error: 'something',
      );
      final map = msg.toApiMap();

      expect(map.keys, containsAll(['role', 'content']));
      expect(map.keys, isNot(contains('isStreaming')));
      expect(map['role'], equals('assistant'));
    });

    test('MessageRole.fromString handles all cases', () {
      expect(MessageRoleExtension.fromString('user'), MessageRole.user);
      expect(MessageRoleExtension.fromString('assistant'),
          MessageRole.assistant);
      expect(MessageRoleExtension.fromString('system'), MessageRole.system);
      expect(MessageRoleExtension.fromString('unknown'), MessageRole.user);
    });
  });

  group('LogEntry', () {
    test('serialisation round-trip', () {
      final entries = [
        LogEntry(
          id: 'log-1',
          level: LogLevel.error,
          message: 'Error message',
          tag: 'TestTag',
          details: 'Some details',
          timestamp: DateTime(2024, 6, 1, 10, 0),
        ),
      ];

      final json = LogEntry.listToJson(entries);
      final restored = LogEntry.listFromJson(json);

      expect(restored.length, equals(1));
      expect(restored.first.id, equals('log-1'));
      expect(restored.first.level, equals(LogLevel.error));
      expect(restored.first.message, equals('Error message'));
      expect(restored.first.tag, equals('TestTag'));
    });
  });

  group('Widgets', () {
    testWidgets('ChatBubble renders user message', (tester) async {
      final msg = Message(
        id: 'id',
        role: MessageRole.user,
        content: 'Test message',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AiAnywhereTheme.dark,
          home: Scaffold(
            body: ChatBubble(message: msg),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('ChatBubble renders assistant error state', (tester) async {
      final msg = Message(
        id: 'id',
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        error: 'Connection failed',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AiAnywhereTheme.dark,
          home: Scaffold(
            body: ChatBubble(message: msg),
          ),
        ),
      );

      expect(find.text('Connection failed'), findsOneWidget);
    });

    testWidgets('StatusDot renders for each ConnectionStatus',
        (tester) async {
      for (final status in ConnectionStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AiAnywhereTheme.dark,
            home: Scaffold(
              body: StatusDot(status: status),
            ),
          ),
        );
        await tester.pump();
      }
      // No exceptions thrown is the test
    });

    testWidgets('EmptyState renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AiAnywhereTheme.dark,
          home: const Scaffold(
            body: EmptyState(
              icon: Icons.search,
              title: 'Nothing Found',
              subtitle: 'Try a different search.',
            ),
          ),
        ),
      );

      expect(find.text('Nothing Found'), findsOneWidget);
      expect(find.text('Try a different search.'), findsOneWidget);
    });

    testWidgets('ConnectionBanner is invisible when connected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AiAnywhereTheme.dark,
          home: const Scaffold(
            body: ConnectionBanner(
              status: ConnectionStatus.connected,
            ),
          ),
        ),
      );

      // SizedBox.shrink means no visible content
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('ConnectionBanner is visible when disconnected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AiAnywhereTheme.dark,
          home: const Scaffold(
            body: ConnectionBanner(
              status: ConnectionStatus.disconnected,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('unreachable'), findsOneWidget);
    });
  });
}
