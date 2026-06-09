# Changelog

All notable changes to `@salesforce/omni-gateway-skills` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- 

## [0.1.1] - 2026-06-09

### Changed

- **`validate-gateway-config`** — Full rewrite based on real-world gateway examples:
  - Corrected: `metadata.namespace` is not required to equal `gateway`; it is optional and user-defined
  - Corrected: `spec.services` inside `ApiInstance` is not required — standalone `Service` + route `PolicyBinding` is equally valid
  - Added: `Extension`, `Secret`, `Contract` resource kinds
  - Added: All 7 `Configuration` sub-kinds (`logging`, `forwardProxy`, `defaultTLS`, `sharedStorage`, `resourceLimits`, `circuitBreaker`, `tracing`)
  - Added: `apiVersion: gateway.mulesoft.com/v1beta1` for `circuitBreaker` and `tracing`
  - Added: Outbound `PolicyBinding` (`targetRef.kind: Service`) for upstream policies
  - Added: Inline policy style (`spec.policies[]` on `ApiInstance`)
  - Added: Multi-document YAML file handling (multiple `---` docs per file)
  - Added: `PolicyBinding.spec.order` and `spec.rules[]` documentation
  - Added: gRPC upstream scheme (`h2://`) and HTTPS port requirement checks
  - Expanded: Misconfigurations table from 5 to 14 entries with severity levels

## [0.1.0] - 2026-06-08 — Preview

Initial preview release.

### Added

- `**install-omni-gateway**` — Install Omni Gateway on Linux (RPM/DEB), Docker, or Kubernetes (Helm).
- `**register-gateway**` — Register a self-managed gateway with Anypoint Platform.
- `**inspect-gateway-logs**` — Parse and interpret gateway log output.
- `**validate-gateway-config**` — Validate `conf.d/` YAML configuration files.
- `**analyze-gateway-dump**` — Interpret diagnostic dump ZIP files.
- `**diagnose-gateway-error**` — Symptom triage router with escalation guidance.

