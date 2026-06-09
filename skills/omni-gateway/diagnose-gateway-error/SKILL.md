---
name: diagnose-gateway-error
description: |
  Diagnose Omni Gateway errors and failures given any combination of log output,
  dump files, or symptom descriptions. Use when the user reports a gateway error
  (5xx, 4xx, gateway unreachable, policy not applying), has log output to
  analyze, needs to decide whether to request debug logs from a customer, or
  needs to determine whether an issue requires escalation to the gateway team.
---

# Diagnose Gateway Error

## Triage by Symptom

| Symptom | First Check | Invoke Skill |
|---------|-------------|-------------|
| 5xx errors on all requests | Upstream connectivity, spec.address binding | `validate-gateway-config` |
| 4xx errors (auth/policy) | PolicyBinding targeting, policy config | `validate-gateway-config` |
| Gateway unreachable / port not responding | Listen address (0.0.0.0 vs localhost), port conflicts | `validate-gateway-config` |
| Policy not applying | PolicyBinding → ApiInstance cross-reference | `validate-gateway-config` |
| `upstream connect error` / connection refused | Upstream service health, routes config | `inspect-gateway-logs` |
| TLS handshake failures | Certificate validity, TLS config in conf.d | `inspect-gateway-logs` |
| `xDS disconnected` / control plane errors | Anypoint connectivity, registration token validity | `inspect-gateway-logs` |
| STARTED state never reached | Registration artifact, conf.d correctness | `register-gateway`, then `validate-gateway-config` |
| Known-good config still failing | Live deployed state may differ from conf.d | `analyze-gateway-dump` |

## By Available Artifact

- **Logs provided** → invoke `inspect-gateway-logs`
- **conf.d directory available** → invoke `validate-gateway-config`
- **Dump file provided** → invoke `analyze-gateway-dump`
- **Symptom description only** → ask the user which artifacts are available before proceeding

## Escalation Decision

### Self-serviceable

These issues can be resolved without escalating to the gateway team:
- Misconfigured `PolicyBinding` (wrong `targetRef`, missing ApiInstance)
- Wrong `spec.address` (using `localhost` instead of `0.0.0.0`)
- Upstream service unreachable (network/firewall issue outside the gateway)
- Expired or revoked Anypoint registration token

### Escalate to Gateway Team

These issues require gateway team involvement:
- Repeated xDS sync failure after verifying a valid configuration
- Envoy process crash (crash loop, OOMKill)
- `STARTED` state never reached after valid registration and correct conf.d
- Issue is reproducible after configuration is confirmed valid by `validate-gateway-config`

## Escalation Package Checklist

Collect all of the following before opening a support ticket:

- [ ] Full gateway logs at debug level (see `inspect-gateway-logs` for how to enable)
- [ ] Diagnostic dump file (see `analyze-gateway-dump` for analysis before escalating)
- [ ] `conf.d/` listing with secrets omitted (file names + kind/name inventory only)
- [ ] `flexctl version` output
- [ ] Platform: Linux / Docker / Kubernetes / CloudHub
- [ ] Reproducible steps or a timeline of when the failure started

## Related Jobs

- `inspect-gateway-logs` — parse log output to surface errors and anomalies
- `validate-gateway-config` — structural and cross-reference validation of conf.d files
- `analyze-gateway-dump` — interpret a diagnostic dump ZIP for live gateway state
