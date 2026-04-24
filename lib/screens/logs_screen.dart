import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/log_entry.dart';
import '../services/log_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _filter;

  @override
  Widget build(BuildContext context) {
    final logService = context.watch<LogService>();
    var entries = logService.entries.reversed.toList();

    if (_filter != null) {
      entries = entries.where((e) => e.level == _filter).toList();
    }

    return Scaffold(
      backgroundColor: AiAnywhereTheme.background,
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          // Filter picker
          PopupMenuButton<LogLevel?>(
            icon: Icon(
              CupertinoIcons.line_horizontal_3_decrease,
              color: _filter != null
                  ? AiAnywhereTheme.accent
                  : AiAnywhereTheme.textSecondary,
            ),
            color: AiAnywhereTheme.surface,
            onSelected: (level) => setState(() => _filter = level),
            itemBuilder: (_) => [
              _filterItem(null, 'All Levels'),
              _filterItem(LogLevel.debug, 'Debug'),
              _filterItem(LogLevel.info, 'Info'),
              _filterItem(LogLevel.warning, 'Warning'),
              _filterItem(LogLevel.error, 'Error'),
            ],
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.trash),
            tooltip: 'Clear Logs',
            color: AiAnywhereTheme.destructive,
            onPressed: () => _confirmClear(context, logService),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const EmptyState(
              icon: CupertinoIcons.doc_text,
              title: 'No Log Entries',
              subtitle: 'App activity will be logged here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const Divider(indent: 0, endIndent: 0, height: 0),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _LogEntryTile(entry: entry);
              },
            ),
    );
  }

  PopupMenuItem<LogLevel?> _filterItem(LogLevel? level, String label) {
    return PopupMenuItem<LogLevel?>(
      value: level,
      child: Row(
        children: [
          if (level != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _levelColor(level),
              ),
            )
          else
            const SizedBox(width: 8),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AiAnywhereTheme.textPrimary)),
          const Spacer(),
          if (_filter == level)
            const Icon(CupertinoIcons.checkmark,
                size: 14, color: AiAnywhereTheme.accent),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, LogService logService) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('All log entries will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () {
              Navigator.pop(context);
              logService.clearLogs();
            },
          ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatefulWidget {
  final LogEntry entry;
  const _LogEntryTile({required this.entry});

  @override
  State<_LogEntryTile> createState() => _LogEntryTileState();
}

class _LogEntryTileState extends State<_LogEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasDetails = entry.details != null && entry.details!.isNotEmpty;

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level indicator
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _levelColor(entry.level).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.level.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _levelColor(entry.level),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.tag != null)
                        Text(
                          entry.tag!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AiAnywhereTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        entry.message,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: AiAnywhereTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm:ss').format(entry.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AiAnywhereTheme.textTertiary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (hasDetails)
                  Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 12,
                    color: AiAnywhereTheme.textSecondary,
                  ),
              ],
            ),
            if (_expanded && hasDetails) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AiAnywhereTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.details!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AiAnywhereTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _levelColor(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return AiAnywhereTheme.textSecondary;
    case LogLevel.info:
      return AiAnywhereTheme.accent;
    case LogLevel.warning:
      return AiAnywhereTheme.warning;
    case LogLevel.error:
      return AiAnywhereTheme.destructive;
  }
}
