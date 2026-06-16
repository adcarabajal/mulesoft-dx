#!/usr/bin/env bash
# Generate the local-mode Flex registration artifact, and — when POLICIES
# in .env contains client-id-enforcement — interactively collect CLIENT_ID
# and CLIENT_SECRET and write them into .env.
#
# Idempotent:
#   - If .run/registration/registration.yaml already exists, refuse to
#     overwrite unless FORCE=1 (regenerating rotates gateway identity and
#     forces a redeploy).
#   - If CLIENT_ID/CLIENT_SECRET are already non-empty in .env, leave them
#     alone unless FORCE=1.
#
# Inputs (env, optional):
#   FORCE=1         — regenerate registration / overwrite credentials even
#                     if they're already populated
#   CLIENT_ID       — non-interactive override (stdin not consulted)
#   CLIENT_SECRET   — non-interactive override
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# --- 1. flexctl present? --------------------------------------------------
if ! command -v flexctl >/dev/null 2>&1; then
  echo "prepare-registration: flexctl not found." >&2
  echo "  Install via the install-omni-gateway skill, then re-run." >&2
  exit 1
fi

# --- 2. .env present? -----------------------------------------------------
if [ ! -f "$ROOT/.env" ]; then
  echo "prepare-registration: .env not found. Run \`cp .env.example .env\` first." >&2
  exit 1
fi

# --- 3. Generate registration --------------------------------------------
REG_FILE="$ROOT/.run/registration/registration.yaml"
if [ -s "$REG_FILE" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "prepare-registration: $REG_FILE already exists — keeping it."
  echo "  Set FORCE=1 to rotate gateway identity (will force a Flex redeploy)."
else
  if [ -s "$REG_FILE" ]; then
    echo "prepare-registration: FORCE=1 set — backing up existing registration to $REG_FILE.bak"
    cp "$REG_FILE" "$REG_FILE.bak"
  fi
  mkdir -p "$ROOT/.run/registration"
  flexctl registration create \
    --connected=false \
    --output-directory="$ROOT/.run/registration"
  echo "prepare-registration: wrote $REG_FILE"
fi

# --- 4. Policy credentials ------------------------------------------------
# Only collect when POLICIES contains client-id-enforcement; otherwise the
# benchmark doesn't need them.
policies_line=$(grep -E '^POLICIES=' "$ROOT/.env" || true)
if ! printf '%s' "$policies_line" | grep -q 'client-id-enforcement'; then
  echo "prepare-registration: POLICIES does not contain client-id-enforcement — skipping credential prompt."
  exit 0
fi

current_id=$(grep -E '^CLIENT_ID='     "$ROOT/.env" | cut -d= -f2- || true)
current_sc=$(grep -E '^CLIENT_SECRET=' "$ROOT/.env" | cut -d= -f2- || true)

if [ -n "$current_id" ] && [ -n "$current_sc" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "prepare-registration: CLIENT_ID and CLIENT_SECRET already set in .env — keeping them."
  echo "  Set FORCE=1 to overwrite."
  exit 0
fi

# Allow non-interactive override via env vars (useful for CI / agent flows).
new_id="${CLIENT_ID:-}"
new_sc="${CLIENT_SECRET:-}"

if [ -z "$new_id" ] || [ -z "$new_sc" ]; then
  if [ ! -t 0 ]; then
    echo "prepare-registration: CLIENT_ID/CLIENT_SECRET required but stdin is not a TTY." >&2
    echo "  Re-run with: CLIENT_ID=... CLIENT_SECRET=... make prepare-registration" >&2
    exit 1
  fi
  echo
  echo "POLICIES contains client-id-enforcement. Enter the consumer credentials"
  echo "issued for an approved Contract on the API instance the benchmark hits."
  echo "(These are NOT your Anypoint Platform org credentials.)"
  echo
  if [ -z "$new_id" ]; then
    read -r -p "CLIENT_ID: " new_id
  fi
  if [ -z "$new_sc" ]; then
    # -s suppresses echo for secret entry
    read -r -s -p "CLIENT_SECRET: " new_sc
    echo
  fi
fi

if [ -z "$new_id" ] || [ -z "$new_sc" ]; then
  echo "prepare-registration: empty credentials — aborting (k6 would 401 every request)." >&2
  exit 1
fi

# --- 5. Write back to .env (one-shot backup) ------------------------------
cp "$ROOT/.env" "$ROOT/.env.bak"

# Detect sed flavor: macOS/BSD requires the empty '' arg after -i.
if sed --version >/dev/null 2>&1; then
  sed_inplace=(sed -i)
else
  sed_inplace=(sed -i '')
fi

# Use # as the delimiter to tolerate / and = in secrets.
if grep -qE '^CLIENT_ID=' "$ROOT/.env"; then
  "${sed_inplace[@]}" "s#^CLIENT_ID=.*#CLIENT_ID=$new_id#" "$ROOT/.env"
else
  echo "CLIENT_ID=$new_id" >> "$ROOT/.env"
fi
if grep -qE '^CLIENT_SECRET=' "$ROOT/.env"; then
  "${sed_inplace[@]}" "s#^CLIENT_SECRET=.*#CLIENT_SECRET=$new_sc#" "$ROOT/.env"
else
  echo "CLIENT_SECRET=$new_sc" >> "$ROOT/.env"
fi

echo "prepare-registration: CLIENT_ID and CLIENT_SECRET written to .env (CLIENT_SECRET redacted from log)."
echo "  Backup at .env.bak"
