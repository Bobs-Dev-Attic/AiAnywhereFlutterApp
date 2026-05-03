import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/server_config.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/section_header.dart';
import '../widgets/status_dot.dart';
import 'server_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AiAnywhereTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add_circled),
            tooltip: 'Add Server',
            onPressed: () => _addServer(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Active Server Status
          if (provider.activeServer != null) ...[
            const SectionHeader(title: 'Active Connection'),
            _ActiveServerCard(provider: provider),
            const SizedBox(height: 24),
          ],

          if (provider.servers.isEmpty) ...[
            const SectionHeader(title: 'First Run Guide'),
            const _OnboardingCard(),
            const SizedBox(height: 20),
          ],

          // Server List
          const SectionHeader(title: 'Servers'),
          if (provider.servers.isEmpty)
            _EmptyServersCard(onAdd: () => _addServer(context))
          else
            _ServerList(provider: provider),

          const SizedBox(height: 24),

          // About section
          const SectionHeader(title: 'About'),
          const _AboutCard(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _addServer(BuildContext context) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute(
        builder: (_) => const ServerEditScreen(),
      ),
    );
  }
}

class _ActiveServerCard extends StatelessWidget {
  final AppProvider provider;
  const _ActiveServerCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final server = provider.activeServer!;
    final status = provider.connectionStatus;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor(status),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ServerTypeIcon(serverType: server.serverType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      server.baseUrl,
                      style: const TextStyle(
                        color: AiAnywhereTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SecurityPill(
                          label: server.useHttps ? 'HTTPS' : 'HTTP',
                          secure: server.useHttps,
                        ),
                        _SecurityPill(
                          label: server.useTailscale ? 'VPN: Tailscale' : 'VPN: Off',
                          secure: server.useTailscale,
                        ),
                        const _SecurityPill(label: 'Cert: Standard', secure: true),
                      ],
                    ),
                  ],
                ),
              ),
              StatusDot(status: status),
            ],
          ),
          if (server.model.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.sparkles,
                  size: 14,
                  color: AiAnywhereTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  server.model,
                  style: const TextStyle(
                    color: AiAnywhereTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (server.useTailscale) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AiAnywhereTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Tailscale',
                      style: TextStyle(
                        color: AiAnywhereTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath,
                      size: 16),
                  label: const Text('Test Connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AiAnywhereTheme.accent,
                    side: const BorderSide(
                        color: AiAnywhereTheme.accent, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  onPressed: () => provider.checkConnection(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _borderColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return AiAnywhereTheme.accentSecondary.withOpacity(0.4);
      case ConnectionStatus.connecting:
        return AiAnywhereTheme.warning.withOpacity(0.4);
      case ConnectionStatus.disconnected:
        return AiAnywhereTheme.divider;
      case ConnectionStatus.error:
        return AiAnywhereTheme.destructive.withOpacity(0.4);
    }
  }
}



class _SecurityPill extends StatelessWidget {
  final String label;
  final bool secure;

  const _SecurityPill({required this.label, required this.secure});

  @override
  Widget build(BuildContext context) {
    final color = secure ? AiAnywhereTheme.accentSecondary : AiAnywhereTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Secure setup checklist', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('1. Add your server and keep HTTPS enabled where available.'),
          SizedBox(height: 6),
          Text('2. Prefer Tailscale IP or MagicDNS names for private access.'),
          SizedBox(height: 6),
          Text('3. Use Test Connection before saving to validate config.'),
        ],
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  final AppProvider provider;
  const _ServerList({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < provider.servers.length; i++) ...[
            if (i > 0) const Divider(indent: 60, endIndent: 0, height: 0),
            _ServerListTile(
              server: provider.servers[i],
              isActive: provider.activeServer?.id == provider.servers[i].id,
              provider: provider,
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerListTile extends StatelessWidget {
  final ServerConfig server;
  final bool isActive;
  final AppProvider provider;

  const _ServerListTile({
    required this.server,
    required this.isActive,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _ServerTypeIcon(serverType: server.serverType),
      title: Text(server.name),
      subtitle: Text(
        '${server.serverType.displayName} · ${server.host}:${server.port}',
        style: const TextStyle(
          color: AiAnywhereTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: AiAnywhereTheme.accentSecondary,
              size: 20,
            ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AiAnywhereTheme.textSecondary,
          ),
        ],
      ),
      onTap: () => _openEditScreen(context),
      onLongPress: () => _showActions(context),
    );
  }

  Future<void> _openEditScreen(BuildContext context) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute(
        builder: (_) => ServerEditScreen(server: server),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(server.name),
        actions: [
          if (!isActive)
            CupertinoActionSheetAction(
              child: const Text('Set as Active'),
              onPressed: () {
                Navigator.pop(context);
                provider.setActiveServer(server.id);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('Edit'),
            onPressed: () {
              Navigator.pop(context);
              _openEditScreen(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Server'),
        content: Text(
            '"${server.name}" and its API key will be permanently deleted.'),
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
              provider.deleteServer(server.id);
            },
          ),
        ],
      ),
    );
  }
}

class _ServerTypeIcon extends StatelessWidget {
  final ServerType serverType;
  const _ServerTypeIcon({required this.serverType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _emoji(serverType),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  String _emoji(ServerType type) {
    switch (type) {
      case ServerType.ollama:
        return '🦙';
      case ServerType.llamaCpp:
        return '🔥';
      case ServerType.lmStudio:
        return '🎬';
    }
  }
}

class _EmptyServersCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyServersCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.wifi_slash,
            size: 40,
            color: AiAnywhereTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Servers Added',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your Ollama, llama.cpp, or LM Studio\nserver to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AiAnywhereTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(CupertinoIcons.add, size: 16),
            label: const Text('Add Server'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(CupertinoIcons.info_circle,
                color: AiAnywhereTheme.accent),
            title: const Text('AI Anywhere'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AiAnywhereTheme.textSecondary,
            ),
          ),
          const Divider(indent: 56, endIndent: 0, height: 0),
          ListTile(
            leading: const Icon(CupertinoIcons.lock_shield,
                color: AiAnywhereTheme.accentSecondary),
            title: const Text('Encrypted Credentials'),
            subtitle: const Text('API keys stored securely on-device'),
          ),
        ],
      ),
    );
  }
}
