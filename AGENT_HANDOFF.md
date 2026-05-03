# Agent Handoff (Token-Efficient Context)

## Project Snapshot
- Flutter mobile client for local/homelab LLM backends (Ollama, llama.cpp, LM Studio).
- Core state: `AppProvider`; network: `ApiService`; persistence: `StorageService`.

## Highest-Risk Areas (Start Here)
1. Platform network security configs are permissive (global cleartext/ATS exceptions).
2. Streaming flow writes large session data repeatedly.
3. SharedPreferences used beyond intended scale for chat payloads.

## Fast Navigation
- Security config: `android/app/src/main/res/xml/network_security_config.xml`, `ios/Runner/Info.plist`
- Networking: `lib/services/api_service.dart`
- State/stream updates: `lib/providers/app_provider.dart`
- Persistence: `lib/services/storage_service.dart`

## Suggested Next Implementation Sequence
1. Tighten transport defaults + environment-based exceptions.
2. Add host/port validator + logging redaction.
3. Migrate chat persistence to DB and throttle stream persistence.
4. Add tests/benchmarks for streaming and large histories.

## Definition of Done for Security Hardening
- No global arbitrary cleartext in production builds.
- Certificate handling policy documented and test-covered.
- Logs redact secrets/PII by default.
- Threat model and secure configuration checklist committed.
