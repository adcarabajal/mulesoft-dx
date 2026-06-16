# Changelog

All notable changes to `@salesforce/omni-gateway-skills` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`run-gateway-benchmark`** — Execute Flex Gateway performance benchmarks on Amazon EKS using the harness under `run-gateway-benchmark/scripts/`. Covers full lifecycle: prerequisites, registration, image push, infra provisioning (`make up`), Flex/upstream deploy, k6 load run, Grafana PNG export, Markdown report retrieval, and teardown. Includes safety guardrails for destructive AWS operations and a scenario cookbook for common parameter combinations.
- **`run-gateway-benchmark`: `make preflight`** — New Makefile target backed by `scripts/preflight.sh`. Read-only checklist that verifies CLIs (`terraform`, `kubectl`, `helm`, `aws`, `docker buildx`, `flexctl`, `jq`, `python3`, `envsubst`, `sha256sum`, `shellcheck`), Docker engine version + daemon liveness (`docker info`), AWS identity/region/profile, `.env`, `.run/registration/registration.yaml`, policy credentials when `client-id-enforcement` is enabled, and `flex-packages` connectivity. Exits non-zero on any gap and prints the remediation command per missing item.
- **`run-gateway-benchmark`: `make prepare-registration`** — New Makefile target backed by `scripts/prepare-registration.sh`. Generates the local-mode `.run/registration/registration.yaml` via `flexctl registration create --connected=false`, and when `POLICIES` includes `client-id-enforcement`, interactively prompts for `CLIENT_ID` / `CLIENT_SECRET` (or accepts them via env vars for non-interactive use) and writes them into `.env`. Idempotent: skips regeneration / overwriting unless `FORCE=1`, with a `.bak` backup when forcing.

## [0.1.0] - 2026-06-11

Initial release.

### Added

- **`install-omni-gateway`** — Install and register Omni Gateway on Linux (Ubuntu/Debian via APT), Docker, or Kubernetes (Helm). Includes parameter gathering, `flexctl registration create` commands per platform, artifact verification, Anypoint Runtime Manager confirmation, and a consolidated troubleshooting table.
- **`inspect-gateway-logs`** — Parse and interpret gateway log output.
- **`validate-gateway-config`** — Validate `conf.d/` YAML configuration files for all resource kinds (ApiInstance, PolicyBinding, Service, Configuration, Extension, Secret, Contract), with cross-reference checks and a structured validation report.
- **`analyze-gateway-dump`** — Interpret diagnostic dump ZIP files.
- **`diagnose-gateway-error`** — Symptom triage router with escalation guidance.
