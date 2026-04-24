import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessions = provider.sessions;

    return Scaffold(
      backgroundColor: AiAnywhereTheme.background,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (sessions.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, provider),
              child: const Text(
                'Clear All',
                style: TextStyle(color: AiAnywhereTheme.destructive),
              ),
            ),
        ],
      ),
      body: sessions.isEmpty
          ? const EmptyState(
              icon: CupertinoIcons.clock,
              title: 'No Conversations Yet',
              subtitle: 'Your chat history will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = provider.activeSession?.id == session.id;
                final lastMessage = session.messages
                    .where((m) => m.role != MessageRole.system)
                    .lastOrNull;

                return ListTile(
                  tileColor: isActive
                      ? AiAnywhereTheme.accent.withOpacity(0.08)
                      : Colors.transparent,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AiAnywhereTheme.accent.withOpacity(0.15)
                          : AiAnywhereTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.chat_bubble_2,
                      size: 20,
                      color: isActive
                          ? AiAnywhereTheme.accent
                          : AiAnywhereTheme.textSecondary,
                    ),
                  ),
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: AiAnywhereTheme.textPrimary,
                    ),
                  ),
                  subtitle: lastMessage != null
                      ? Text(
                          lastMessage.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AiAnywhereTheme.textSecondary,
                            fontSize: 13,
                          ),
                        )
                      : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(session.updatedAt),
                        style: const TextStyle(
                          color: AiAnywhereTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.messages.where((m) => m.role != MessageRole.system).length} msgs',
                        style: const TextStyle(
                          color: AiAnywhereTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await provider.setActiveSession(session.id);
                  },
                  onLongPress: () => _confirmDelete(context, provider, session.id),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      return DateFormat.jm().format(dt);
    }
    return DateFormat.MMMd().format(dt);
  }

  void _confirmDelete(
    BuildContext context,
    AppProvider provider,
    String sessionId,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
            'This conversation will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              provider.deleteSession(sessionId);
            },
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, AppProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
            'All conversations will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear All'),
            onPressed: () async {
              Navigator.pop(context);
              final sessions = List.of(provider.sessions);
              for (final s in sessions) {
                await provider.deleteSession(s.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
