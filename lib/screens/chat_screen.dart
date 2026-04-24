import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/connection_banner.dart';
import '../widgets/message_input.dart';
import '../widgets/status_dot.dart';
import '../widgets/empty_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final messages = provider.messages
        .where((m) => m.role != MessageRole.system)
        .toList();

    // Scroll when new messages arrive
    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AiAnywhereTheme.background,
      appBar: _buildAppBar(context, provider),
      body: Column(
        children: [
          // Connection status banner
          ConnectionBanner(status: provider.connectionStatus),

          // Error snackbar area
          if (provider.errorMessage != null)
            _ErrorBanner(
              message: provider.errorMessage!,
              onDismiss: provider.clearError,
            ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(context, provider)
                : _buildMessageList(context, messages),
          ),

          // Message input
          MessageInput(
            onSend: (text) => provider.sendMessage(text),
            isLoading: provider.isStreaming,
            enabled: provider.activeServer != null,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppProvider provider,
  ) {
    return AppBar(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Column(
        children: [
          Text(
            provider.activeSession?.title ?? 'AI Anywhere',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.41,
            ),
          ),
          if (provider.activeServer != null)
            Text(
              provider.activeServer!.name,
              style: const TextStyle(
                fontSize: 12,
                color: AiAnywhereTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: StatusDot(status: provider.connectionStatus),
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.pencil_circle),
          tooltip: 'New Chat',
          onPressed: () => _startNewChat(context, provider),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppProvider provider) {
    if (provider.activeServer == null) {
      return const EmptyState(
        icon: CupertinoIcons.wifi_slash,
        title: 'No Server Configured',
        subtitle:
            'Add your llama.cpp, Ollama, or LM Studio server in Settings to get started.',
      );
    }
    return EmptyState(
      icon: CupertinoIcons.chat_bubble_2,
      title: 'Start a Conversation',
      subtitle:
          'Connected to ${provider.activeServer!.name}.\nType a message below to begin.',
    );
  }

  Widget _buildMessageList(BuildContext context, List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatBubble(message: message),
        );
      },
    );
  }

  Future<void> _startNewChat(
    BuildContext context,
    AppProvider provider,
  ) async {
    if (provider.activeServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure a server first.'),
          backgroundColor: AiAnywhereTheme.surface,
        ),
      );
      return;
    }
    await provider.newChat();
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.destructive.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AiAnywhereTheme.destructive.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: AiAnywhereTheme.destructive,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AiAnywhereTheme.destructive,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              CupertinoIcons.xmark,
              color: AiAnywhereTheme.destructive,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}
