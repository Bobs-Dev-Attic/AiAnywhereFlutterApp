import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final bool isLoading;
  final bool enabled;

  const MessageInput({
    super.key,
    required this.onSend,
    required this.isLoading,
    this.enabled = true,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading || !widget.enabled) return;
    _controller.clear();
    setState(() => _hasText = false);
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(
          top: BorderSide(color: AiAnywhereTheme.divider, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AiAnywhereTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AiAnywhereTheme.accent.withOpacity(0.4)
                      : AiAnywhereTheme.divider,
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                enabled: widget.enabled && !widget.isLoading,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontSize: 15,
                  color: AiAnywhereTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Message'
                      : 'Configure a server first…',
                  hintStyle: const TextStyle(
                    color: AiAnywhereTheme.textTertiary,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send / Stop button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.isLoading
                ? _StopButton(key: const ValueKey('stop'))
                : _SendButton(
                    key: const ValueKey('send'),
                    enabled: _hasText && widget.enabled,
                    onTap: _send,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AiAnywhereTheme.accent
              : AiAnywhereTheme.textTertiary,
        ),
        child: const Icon(
          CupertinoIcons.arrow_up,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AiAnywhereTheme.destructive,
      ),
      child: const Icon(
        CupertinoIcons.stop_fill,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}
