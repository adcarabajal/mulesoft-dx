#!/usr/bin/env bash
# Part of mule-dev skill
#
# Step 0 helper — creates a minimal Mule project that Phase 1 design
# commands (describe-connector, config-detail, source-detail,
# operation-detail) can point `--project` at.
#
# These CLI subcommands REQUIRE `--project <path>` and reject paths
# without a pom.xml ("Project not found at: <path>"). Phase 1, by
# design, runs BEFORE `dx project create` — so it has no real project
# to aim at. This script provisions a disposable "probe" project with
# just enough on-disk structure (a 6-line mule-application pom) for
# the design commands to succeed. The real user-facing project is
# created in Phase 2 Step 7; the probe is never shipped, never built,
# and is cleaned up together with the workspace.
#
# Outputs (both relative to the current working directory):
#   tmp/mule-dev-probe/pom.xml   — the disposable probe project
#   tmp/mule-dev-probe.json      — {"probe_project_path": "<absolute>"}
#
# Paths are workspace-relative by design. Earlier versions wrote under
# /tmp, which is shared per-user per-machine and caused concurrent
# mule-dev sessions on the same machine to clobber each other's
# probe state. Writing under the current workspace keeps every session
# fully isolated — it matches the convention already used by
# tmp/connector-versions/ and tmp/connector-metadata/.
#
# This script OWNS tmp/mule-dev-probe.json exclusively. It does not
# read, merge, or modify any other state file (including the
# validate_prerequisites.sh env file) — scripts bundled with this
# skill keep their outputs fully isolated so re-running any one of
# them can never clobber another's state.
#
# Idempotent: writing the probe directory and the state file are both
# unconditional safe writes; re-running the script is a no-op beyond
# re-touching those two paths.
#
# Exit code:
#   0  probe ready; state file written
#   1  jq unavailable, or write failure
set -u

PROBE_DIR="${MULE_DEV_PROBE_DIR:-tmp/mule-dev-probe}"
STATE_FILE="${MULE_DEV_PROBE_STATE_FILE:-tmp/mule-dev-probe.json}"

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq is required to write $STATE_FILE" >&2
    exit 1
fi

mkdir -p "$PROBE_DIR"

POM="$PROBE_DIR/pom.xml"
if [ ! -f "$POM" ]; then
    cat >"$POM" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.mule.dev.probe</groupId>
  <artifactId>mule-dev-probe</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <packaging>mule-application</packaging>
</project>
XML
    echo "✅ Probe project created at $PROBE_DIR"
else
    echo "✅ Probe project already exists at $PROBE_DIR"
fi

# Resolve to an absolute path before writing the state file — downstream
# commands (describe-connector, config-detail, etc.) require --project
# to be a path the CLI can resolve regardless of the caller's cwd.
PROBE_ABS="$(cd "$PROBE_DIR" && pwd)"

TMP_FILE="$(mktemp "${STATE_FILE}.XXXXXX")"
if jq -n --arg path "$PROBE_ABS" '{probe_project_path: $path}' >"$TMP_FILE"; then
    mv "$TMP_FILE" "$STATE_FILE"
    echo "📝 Wrote $STATE_FILE (probe_project_path=$PROBE_ABS)"
else
    rm -f "$TMP_FILE"
    echo "❌ Failed to write $STATE_FILE" >&2
    exit 1
fi
