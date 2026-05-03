# TODO (Prioritized)

## P0 — Immediate Security & Privacy
- [x] **Enforce transport security defaults**: disable arbitrary cleartext traffic; allow HTTP only for explicitly whitelisted RFC1918/Tailscale hosts in debug/development. Move production to HTTPS-only with cert validation/pinning options. (Android `network_security_config.xml`, iOS `Info.plist`)
- [x] **Add SSRF/host validation guardrails** for user-provided host/port to prevent abuse (loopback/public endpoints, malformed hostnames, dangerous schemes). 
- [x] **Redact secrets from logs** (API keys, auth headers, prompt fragments with PII) and add structured log-level policies for release builds.
- [ ] **Add auth hardening**: optional mTLS / self-signed cert trust onboarding flow for homelab targets, plus certificate fingerprint verification.

## P1 — Reliability, Memory, and Performance
- [x] **Stop rewriting full session payloads on every streamed token**; introduce buffered streaming updates (e.g., update UI every 50–100ms, persist at message end/checkpoints).
- [ ] **Move chat history from SharedPreferences JSON blob to local DB** (Hive/Isar/SQLite) with indexed session/messages tables and pagination.
- [ ] **Bound in-memory message history** for rendering large chats; use lazy list virtualization and chunked markdown parsing.
- [x] **Add cancellation + backpressure controls** for active streams to avoid runaway resource usage when switching screens.

## P2 — Secure Engineering Best Practices
- [x] Add **input validation schema** for all server settings (host, port range, timeout, model id).
- [ ] Add **threat-model documentation** (assets, attack surfaces, trust boundaries, mitigations) and update per release.
- [ ] Add **dependency/security scanning** in CI (SCA + secret scanning + lint + tests).
- [x] Ensure release builds disable verbose debug logs and tighten error surfaces (no raw server bodies to end users).

## P3 — UX/Product Improvements
- [x] Add **security posture indicators** in UI (HTTP vs HTTPS, cert status, VPN connected).
- [x] Improve **first-run onboarding** with secure defaults and guided server setup validation.
- [ ] Add **large-response UX optimizations** (pause generation, jump-to-bottom, copy code block buttons, partial rendering states).
- [ ] Add **offline/error recovery patterns** (retry policy, reconnect guidance, diagnostics export bundle).

## P4 — Testing & Observability
- [ ] Add unit/integration tests for streaming parser edge cases (SSE fragmentation, malformed JSON lines, timeout transitions).
- [ ] Add performance benchmarks (long chats, 10k+ messages, low-memory devices).
- [ ] Add privacy-safe telemetry hooks (opt-in) for failure rates/latency percentiles.


## Running Log
- [x] Enforced HTTPS-first transport policy in Android/iOS platform configs.
- [x] Added host and port validation guardrails in server settings form/model.
- [x] Added log redaction for auth/API key secrets before persistence/output.
- [x] Added throttled in-memory streaming updates plus final persistence checkpoint.
- [x] Added stream cancellation hook and cancellation handling path.

- [x] Added centralized `ServerValidation` schema checks for port/timeout/model-id constraints.
- [x] Added Settings UI security posture pills (transport, VPN, cert handling baseline).
- [x] Added first-run setup checklist card with secure configuration guidance.
- [x] Reduced release logging verbosity and suppressed raw detail payloads in release builds.
