# Senior Engineering Review

## Scope
Review covered architecture docs and implementation in networking, storage, state management, and platform security configuration.

## Key Findings

### 1) Transport Security Is Overly Permissive (High)
- Android allows global cleartext traffic in base config.
- iOS ATS has `NSAllowsArbitraryLoads=true`, allowing insecure HTTP broadly.
- Risk: MITM exposure outside trusted VPN assumptions; accidental insecure deployments.

### 2) Potential Memory/IO Pressure During Streaming (High)
- Provider persists full session payload during stream updates; each token/chunk can trigger full JSON rewrite in SharedPreferences.
- Risk: jank, battery drain, storage churn, and scalability limits for long chats.

### 3) Storage Model Does Not Scale (Medium/High)
- Chat sessions/messages/logs are serialized blobs in SharedPreferences.
- Risk: high parse/serialize overhead and corruption sensitivity for larger datasets.

### 4) Host/Endpoint Trust Boundary Needs Hardening (Medium)
- User-configurable host/port with minimal validation can target unintended endpoints.
- Risk: SSRF-like behavior from mobile context and unsafe network probing.

### 5) Logging Privacy Controls Need Tightening (Medium)
- Error/details and connection strings are logged; without strict redaction policy, sensitive data may leak.

### 6) UX Security Signaling Gaps (Medium)
- App does not clearly signal insecure transport/certificate posture.
- Users can unknowingly run insecure configuration.

## Recommended Technical Direction
- Use HTTPS-by-default, per-environment exceptions, and optional certificate pinning/fingerprint trust onboarding for homelab certs.
- Replace SharedPreferences chat persistence with Isar/SQLite schema and append-only message writes.
- Add streamed rendering throttling (frame-coalesced updates) and persistence checkpoints.
- Build validation/normalization for host, port, timeouts, model names; reject dangerous values.
- Add redaction middleware in logging pipeline and reduced verbosity in release.

## Suggested Services/Tools
- **Storage**: Isar (fast local object store) or Drift/SQLite for strong query/indexing.
- **Security scanning**: GitHub Advanced Security alternatives (Trivy, Gitleaks, Dependabot/Snyk).
- **Monitoring**: privacy-first telemetry (self-hosted Sentry relay with PII scrubbing, or OpenTelemetry collector).

## UX Perspective Notes
- Introduce a setup wizard with secure defaults and automatic diagnostics.
- Show explicit badges: `Tailscale`, `HTTPS`, `Cert verified`, `Local only`.
- Add long-generation controls: pause/stop/regenerate and chunked rendering for readability.

## White-Hat / Pentest Perspective
Top attack paths to test:
1. MITM against HTTP endpoints / downgraded transport.
2. Malicious local server returning oversized/invalid streaming payloads (DoS, parser stress).
3. Host configuration abuse to probe unintended network services.
4. Log exfiltration of sensitive tokens/prompts via debug exports.

