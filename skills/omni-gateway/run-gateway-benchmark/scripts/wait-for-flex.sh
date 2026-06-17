#!/usr/bin/env bash
set -euo pipefail

ns="${1:-flex}"
deploy="${2:-flex-gateway}"
timeout="${3:-180s}"

echo "Waiting for deployment/$deploy in ns/$ns to roll out..."
kubectl -n "$ns" rollout status deploy/"$deploy" --timeout="$timeout"

echo "Waiting for at least one ready pod..."
# The chart labels pods `app=flex-gateway` (not the app.kubernetes.io/name
# convention). Match the deploy's own selector to stay correct if that changes.
kubectl -n "$ns" wait --for=condition=Ready pod \
  -l app="$deploy" \
  --timeout="$timeout"

echo "Flex is ready."
