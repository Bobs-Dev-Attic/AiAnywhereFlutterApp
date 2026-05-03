import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/server_config.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart' show ConnectionStatus;
import '../theme.dart';
import '../widgets/section_header.dart';
import '../widgets/status_dot.dart';

class ServerEditScreen extends StatefulWidget {
  final ServerConfig? server;

  const ServerEditScreen({super.key, this.server});

  bool get isEditing => server != null;

  @override
  State<ServerEditScreen> createState() => _ServerEditScreenState();
}

class _ServerEditScreenState extends State<ServerEditScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _systemPromptController = TextEditingController();

  ServerType _serverType = ServerType.ollama;
  bool _useTailscale = false;
  bool _useHttps = false;
  int _timeoutSeconds = 30;
  int _maxTokens = 2048;
  double _temperature = 0.7;
  bool _showApiKey = false;

  ConnectionStatus? _testStatus;
  bool _testing = false;
  List<String> _availableModels = [];
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    _populateFromServer();
  }

  void _populateFromServer() {
    final s = widget.server;
    if (s == null) {
      _serverType = ServerType.ollama;
      _portController.text = ServerType.ollama.defaultPort;
      _hostController.text = '100.64.0.1';
      _useTailscale = true;
      _nameController.text = 'Home Ollama';
      _modelController.text = ServerType.ollama.defaultModel;
      _systemPromptController.text = 'You are a helpful assistant.';
      return;
    }

    _nameController.text = s.name;
    _hostController.text = s.host;
    _portController.text = s.port;
    _modelController.text = s.model;
    _serverType = s.serverType;
    _useTailscale = s.useTailscale;
    _useHttps = s.useHttps;
    _timeoutSeconds = s.timeoutSeconds;
    _maxTokens = s.maxTokens;
    _temperature = s.temperature;
    _systemPromptController.text = s.systemPrompt;

    // Load existing API key
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      final key = await provider.getApiKey(s.id);
      if (key != null && mounted) {
        setState(() => _apiKeyController.text = key);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiAnywhereTheme.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Server' : 'Add Server'),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              widget.isEditing ? 'Save' : 'Add',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Server Type
            const SectionHeader(title: 'Server Type'),
            _ServerTypePicker(
              selected: _serverType,
              onChanged: (type) {
                setState(() {
                  // Only update port if user hasn't customised it
                  final currentPort = _portController.text;
                  final wasDefault = ServerType.values.any(
                    (t) => t.defaultPort == currentPort,
                  );
                  _serverType = type;
                  if (currentPort.isEmpty || wasDefault) {
                    _portController.text = type.defaultPort;
                  }
                  if (_modelController.text.isEmpty) {
                    _modelController.text = type.defaultModel;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Basic Settings
            const SectionHeader(title: 'Connection'),
            _FormCard(
              children: [
                _FormField(
                  label: 'Display Name',
                  controller: _nameController,
                  placeholder: 'e.g. Home Ollama',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const _Separator(),
                _FormField(
                  label: 'Host / IP',
                  controller: _hostController,
                  placeholder: '100.64.0.1 or hostname',
                  keyboardType: TextInputType.url,
                  validator: (v) => v == null ? 'Host is required' : ServerConfig.validateHost(v),
                  hint: _useTailscale
                      ? 'Use Tailscale IP (100.x.x.x) or MagicDNS name'
                      : null,
                ),
                const _Separator(),
                _FormField(
                  label: 'Port',
                  controller: _portController,
                  placeholder: _serverType.defaultPort,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Port is required';
                    return ServerValidation.validatePort(v);
                  },
                ),
                const _Separator(),
                _SwitchRow(
                  label: 'Tailscale VPN',
                  subtitle: 'Connect via Tailscale encrypted network',
                  value: _useTailscale,
                  onChanged: (v) => setState(() => _useTailscale = v),
                ),
                const _Separator(),
                _SwitchRow(
                  label: 'Use HTTPS',
                  subtitle: 'Enable for TLS-secured endpoints',
                  value: _useHttps,
                  onChanged: (v) => setState(() => _useHttps = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Model & Auth
            const SectionHeader(title: 'Model & Authentication'),
            _FormCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Model Name',
                        controller: _modelController,
                        placeholder: _serverType.defaultModel,
                        validator: (v) => ServerValidation.validateModelId(v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 16, top: 8),
                      child: TextButton(
                        onPressed: _availableModels.isEmpty
                            ? _fetchModels
                            : null,
                        child: _loadingModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Fetch'),
                      ),
                    ),
                  ],
                ),
                if (_availableModels.isNotEmpty) ...[
                  const _Separator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Models',
                          style: TextStyle(
                            color: AiAnywhereTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _availableModels
                              .map((m) => GestureDetector(
                                    onTap: () => setState(
                                        () => _modelController.text = m),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _modelController.text == m
                                            ? AiAnywhereTheme.accent
                                                .withOpacity(0.2)
                                            : AiAnywhereTheme.surfaceElevated,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _modelController.text == m
                                              ? AiAnywhereTheme.accent
                                                  .withOpacity(0.5)
                                              : AiAnywhereTheme.divider,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        m,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _modelController.text == m
                                              ? AiAnywhereTheme.accent
                                              : AiAnywhereTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const _Separator(),
                _ApiKeyField(
                  controller: _apiKeyController,
                  showKey: _showApiKey,
                  onToggleVisibility: () =>
                      setState(() => _showApiKey = !_showApiKey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Generation Parameters
            const SectionHeader(title: 'Generation Parameters'),
            _FormCard(
              children: [
                _SliderRow(
                  label: 'Temperature',
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 20,
                  display: _temperature.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _temperature = v),
                ),
                const _Separator(),
                _StepperRow(
                  label: 'Max Tokens',
                  value: _maxTokens,
                  step: 256,
                  min: 256,
                  max: 8192,
                  onChanged: (v) => setState(() => _maxTokens = v),
                ),
                const _Separator(),
                _StepperRow(
                  label: 'Timeout (s)',
                  value: _timeoutSeconds,
                  step: 10,
                  min: 10,
                  max: 120,
                  onChanged: (v) => setState(() => _timeoutSeconds = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // System Prompt
            const SectionHeader(title: 'System Prompt'),
            _FormCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _systemPromptController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'You are a helpful assistant.',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test Connection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_2_circlepath,
                            size: 16,
                          ),
                    label: const Text('Test Connection'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: AiAnywhereTheme.accent,
                      side: const BorderSide(
                          color: AiAnywhereTheme.accent, width: 0.5),
                    ),
                    onPressed: _testing ? null : _testConnection,
                  ),
                  if (_testStatus != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StatusDot(status: _testStatus!),
                        const SizedBox(width: 8),
                        Text(
                          _testStatusLabel(_testStatus!),
                          style: TextStyle(
                            color: _testStatusColor(_testStatus!),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (widget.isEditing) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AiAnywhereTheme.destructive,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => _deleteServer(context),
                  child: const Text('Delete Server'),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    final id = widget.server?.id ?? _uuid.v4();

    final config = ServerConfig(
      id: id,
      name: _nameController.text.trim(),
      serverType: _serverType,
      host: _hostController.text.trim(),
      port: _portController.text.trim(),
      model: _modelController.text.trim(),
      useTailscale: _useTailscale,
      useHttps: _useHttps,
      timeoutSeconds: _timeoutSeconds.clamp(ServerValidation.minTimeoutSeconds, ServerValidation.maxTimeoutSeconds),
      maxTokens: _maxTokens,
      temperature: _temperature,
      systemPrompt: _systemPromptController.text.trim(),
    );

    final apiKey = _apiKeyController.text.trim();

    if (widget.isEditing) {
      await provider.updateServer(config, apiKey: apiKey.isEmpty ? null : apiKey);
    } else {
      await provider.addServer(config, apiKey: apiKey.isEmpty ? null : apiKey);
      // Auto-set as active if it's the first server
      if (provider.servers.length == 1) {
        await provider.setActiveServer(id);
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testStatus = null;
    });

    final config = ServerConfig(
      id: 'test',
      name: _nameController.text,
      serverType: _serverType,
      host: _hostController.text.trim(),
      port: _portController.text.trim(),
      useHttps: _useHttps,
      timeoutSeconds: _timeoutSeconds.clamp(ServerValidation.minTimeoutSeconds, ServerValidation.maxTimeoutSeconds),
    );

    final provider = context.read<AppProvider>();
    final status = await provider.testConnectionDirect(
      config,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _testing = false;
        _testStatus = status;
      });
    }
  }

  Future<void> _fetchModels() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loadingModels = true);

    final config = ServerConfig(
      id: 'fetch',
      name: _nameController.text,
      serverType: _serverType,
      host: _hostController.text.trim(),
      port: _portController.text.trim(),
      useHttps: _useHttps,
      timeoutSeconds: _timeoutSeconds.clamp(ServerValidation.minTimeoutSeconds, ServerValidation.maxTimeoutSeconds),
    );

    final provider = context.read<AppProvider>();
    final models = await provider.listModelsDirect(
      config,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _loadingModels = false;
        _availableModels = models;
      });
    }
  }

  Future<void> _deleteServer(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Delete "${widget.server!.name}"?'),
        content: const Text(
            'This server and its encrypted API key will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppProvider>().deleteServer(widget.server!.id);
      Navigator.pop(context);
    }
  }

  String _testStatusLabel(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return 'Connected successfully';
      case ConnectionStatus.connecting:
        return 'Connecting…';
      case ConnectionStatus.disconnected:
        return 'Cannot reach server';
      case ConnectionStatus.error:
        return 'Connection failed';
    }
  }

  Color _testStatusColor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return AiAnywhereTheme.accentSecondary;
      case ConnectionStatus.connecting:
        return AiAnywhereTheme.warning;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        return AiAnywhereTheme.destructive;
    }
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _ServerTypePicker extends StatelessWidget {
  final ServerType selected;
  final ValueChanged<ServerType> onChanged;

  const _ServerTypePicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ServerType.values.map((type) {
          final isSelected = type == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AiAnywhereTheme.accent.withOpacity(0.15)
                      : AiAnywhereTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AiAnywhereTheme.accent
                        : AiAnywhereTheme.divider,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _emoji(type),
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AiAnywhereTheme.accent
                            : AiAnywhereTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AiAnywhereTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? hint;

  const _FormField({
    required this.label,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.validator,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AiAnywhereTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  validator: validator,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AiAnywhereTheme.textSecondary,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AiAnywhereTheme.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  final TextEditingController controller;
  final bool showKey;
  final VoidCallback onToggleVisibility;

  const _ApiKeyField({
    required this.controller,
    required this.showKey,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.lock_shield,
                  size: 14,
                  color: AiAnywhereTheme.accentSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  'API Key',
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: !showKey,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                color: AiAnywhereTheme.textSecondary,
              ),
              decoration: InputDecoration(
                hintText: 'Optional',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                suffixIcon: GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    showKey
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    size: 16,
                    color: AiAnywhereTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AiAnywhereTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              display,
              style: const TextStyle(
                fontSize: 15,
                color: AiAnywhereTheme.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int step, min, max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(CupertinoIcons.minus_circle,
                color: AiAnywhereTheme.accent),
            onPressed: value > min
                ? () => onChanged(value - step)
                : null,
          ),
          SizedBox(
            width: 60,
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle,
                color: AiAnywhereTheme.accent),
            onPressed: value < max
                ? () => onChanged(value + step)
                : null,
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Divider(indent: 16, endIndent: 0, height: 0);
  }
}
