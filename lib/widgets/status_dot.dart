import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// A small coloured dot indicating connection status.
class StatusDot extends StatelessWidget {
  final ConnectionStatus status;
  final double size;

  const StatusDot({
    super.key,
    required this.status,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color(status),
        boxShadow: status == ConnectionStatus.connected
            ? [
                BoxShadow(
                  color: AiAnywhereTheme.accentSecondary.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Color _color(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return AiAnywhereTheme.accentSecondary;
      case ConnectionStatus.connecting:
        return AiAnywhereTheme.warning;
      case ConnectionStatus.disconnected:
        return AiAnywhereTheme.textTertiary;
      case ConnectionStatus.error:
        return AiAnywhereTheme.destructive;
    }
  }
}
