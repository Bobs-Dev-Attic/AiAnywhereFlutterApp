import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/message.dart';
import '../theme.dart';

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(message: message);
    }
    return _AssistantBubble(message: message);
  }
}

class _UserBubble extends StatelessWidget {
  final Message message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AiAnywhereTheme.userBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final Message message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Avatar
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: AiAnywhereTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('✦', style: TextStyle(fontSize: 14)),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AiAnywhereTheme.assistantBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: message.hasError
                  ? Border.all(
                      color: AiAnywhereTheme.destructive.withOpacity(0.4),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.hasError) ...[
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        color: AiAnywhereTheme.destructive,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message.error!,
                          style: const TextStyle(
                            color: AiAnywhereTheme.destructive,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (message.content.isEmpty && message.isStreaming) ...[
                  _TypingIndicator(),
                ] else ...[
                  MarkdownBody(
                    data: message.content,
                    styleSheet: _markdownStyleSheet,
                    selectable: true,
                  ),
                  if (message.isStreaming) ...[
                    const SizedBox(height: 4),
                    _StreamingCursor(),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  static final _markdownStyleSheet = MarkdownStyleSheet(
    p: const TextStyle(
      color: AiAnywhereTheme.textPrimary,
      fontSize: 15,
      height: 1.5,
    ),
    code: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: AiAnywhereTheme.accent,
      backgroundColor: Colors.transparent,
    ),
    codeblockDecoration: BoxDecoration(
      color: AiAnywhereTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
    ),
    blockquoteDecoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: AiAnywhereTheme.accent, width: 3),
      ),
    ),
    h1: const TextStyle(
      color: AiAnywhereTheme.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    h2: const TextStyle(
      color: AiAnywhereTheme.textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    h3: const TextStyle(
      color: AiAnywhereTheme.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    strong: const TextStyle(
      color: AiAnywhereTheme.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    em: const TextStyle(
      color: AiAnywhereTheme.textSecondary,
      fontStyle: FontStyle.italic,
    ),
    listBullet: const TextStyle(color: AiAnywhereTheme.accent),
  );
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(
          reverse: true,
          period: Duration(milliseconds: 600 + i * 150),
        ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AiAnywhereTheme.textSecondary
                  .withOpacity(_animations[i].value),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _controller.value,
        child: const Text(
          '▌',
          style: TextStyle(
            color: AiAnywhereTheme.accent,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
