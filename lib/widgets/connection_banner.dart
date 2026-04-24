import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Shows a thin banner at the top of the chat screen indicating connection
/// status. Animates in when disconnected or errored.
class ConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, color) = _label(status);
    if (status == ConnectionStatus.connected) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _visible(status) ? 28 : 0,
      color: color.withOpacity(0.15),
      child: _visible(status)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == ConnectionStatus.connecting)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(
                          AiAnywhereTheme.warning),
                    ),
                  )
                else
                  Icon(
                    status == ConnectionStatus.disconnected
                        ? Icons.wifi_off_rounded
                        : Icons.error_outline_rounded,
                    size: 12,
                    color: color,
                  ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  bool _visible(ConnectionStatus s) =>
      s != ConnectionStatus.connected;

  (String, Color) _label(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return ('Connected', AiAnywhereTheme.accentSecondary);
      case ConnectionStatus.connecting:
        return ('Connecting to server…', AiAnywhereTheme.warning);
      case ConnectionStatus.disconnected:
        return ('Server unreachable — check Tailscale',
            AiAnywhereTheme.destructive);
      case ConnectionStatus.error:
        return ('Connection error', AiAnywhereTheme.destructive);
    }
  }
}
