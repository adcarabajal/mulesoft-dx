# Changelog

All notable changes to `@salesforce/omni-gateway-skills` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-11

Initial release.

### Added

- **`install-omni-gateway`** — Install and register Omni Gateway on Linux (Ubuntu/Debian via APT), Docker, or Kubernetes (Helm). Includes parameter gathering, `flexctl registration create` commands per platform, artifact verification, Anypoint Runtime Manager confirmation, and a consolidated troubleshooting table.
- **`inspect-gateway-logs`** — Parse and interpret gateway log output.
- **`validate-gateway-config`** — Validate `conf.d/` YAML configuration files for all resource kinds (ApiInstance, PolicyBinding, Service, Configuration, Extension, Secret, Contract), with cross-reference checks and a structured validation report.
- **`analyze-gateway-dump`** — Interpret diagnostic dump ZIP files.
- **`diagnose-gateway-error`** — Symptom triage router with escalation guidance.
