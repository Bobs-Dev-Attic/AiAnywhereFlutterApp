# AI Anywhere

A Flutter app that lets you connect to your home AI server — **llama.cpp**, **Ollama**, or **LM Studio** — securely over your **Tailscale** VPN.

![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🦙 **Multi-backend support** — Ollama, llama.cpp, and LM Studio (OpenAI-compatible)
- 🔒 **Encrypted credentials** — API keys stored in encrypted secure storage (Android Keystore / iOS Keychain)
- 🌐 **Tailscale-first** — optimised for Tailscale IP/MagicDNS hostnames; works with any reachable host
- 💬 **Streaming responses** — real-time token-by-token streaming with live typing indicator
- 📋 **Markdown rendering** — code blocks, bold, headers all rendered properly
- 🔍 **Model discovery** — fetch available models from your server with one tap
- 🗂 **Conversation history** — full history with auto-generated titles
- 📊 **In-app logging** — filterable debug/info/warning/error log viewer
- 🎨 **Steve Jobs-approved UI** — dark, minimal, purposeful design inspired by Apple HIG

## Architecture

```
lib/
├── main.dart                  # App entry point & DI setup
├── theme.dart                 # Apple-inspired dark theme
├── models/
│   ├── server_config.dart     # Server connection settings
│   ├── message.dart           # Chat message & session models
│   └── log_entry.dart         # Log entry model
├── services/
│   ├── storage_service.dart   # Persistent + encrypted storage
│   ├── api_service.dart       # HTTP API (Ollama, LM Studio, llama.cpp)
│   └── log_service.dart       # Structured logging
├── providers/
│   └── app_provider.dart      # ChangeNotifier state management
├── screens/
│   ├── main_shell.dart        # Bottom navigation shell
│   ├── chat_screen.dart       # Chat interface
│   ├── history_screen.dart    # Conversation history
│   ├── settings_screen.dart   # Server management
│   ├── server_edit_screen.dart # Add/edit server
│   └── logs_screen.dart       # Log viewer
└── widgets/
    ├── chat_bubble.dart       # User & assistant message bubbles
    ├── connection_banner.dart  # Status banner
    ├── message_input.dart     # Compose bar with send button
    ├── status_dot.dart        # Connection status indicator
    ├── section_header.dart    # iOS-style section labels
    └── empty_state.dart       # Empty state placeholder
```

## Supported Backends

| Server     | Default Port | API Endpoint           |
|------------|-------------|------------------------|
| Ollama     | 11434       | `/api/chat`            |
| llama.cpp  | 8080        | `/v1/chat/completions` |
| LM Studio  | 1234        | `/v1/chat/completions` |

## Setup

### Prerequisites

- Flutter 3.27+
- A running AI server on your local network or accessible via Tailscale

### Build

```bash
flutter pub get
flutter run                 # debug
flutter build apk --release # Android release
flutter build ios --release --no-codesign  # iOS
```

### Connecting via Tailscale

1. Install [Tailscale](https://tailscale.com) on both your phone and the machine running the AI server
2. In **Settings → Add Server**, enter:
   - **Host**: your machine's Tailscale IP (`100.x.x.x`) or MagicDNS name
   - **Port**: the server's default port (see table above)
   - **Enable Tailscale** toggle: on
3. Tap **Test Connection** to verify

## Security

- API keys are stored using `flutter_secure_storage` — encrypted with Android Keystore on Android and iOS Keychain on iOS
- No credentials are ever transmitted outside your Tailscale network
- All traffic flows through Tailscale's WireGuard encryption

## License

MIT
