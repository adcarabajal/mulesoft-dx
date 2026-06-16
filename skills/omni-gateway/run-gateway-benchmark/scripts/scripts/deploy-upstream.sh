#!/usr/bin/env bash
# Deploy (or re-deploy) the bench-upstream Deployment.
#
# Idempotent: hashes the rendered Deployment YAML, compares to the
# `bench/spec-hash` label on the live Deployment, and skips kubectl apply
# when nothing changed. This is what makes back-to-back `make benchmark`
# runs cheap when only k6 knobs change.
#
# Inputs:
#   AWS_REGION (env, required)        — for `aws ecr describe-images` preflight.
#   $1 (optional)                     — destination YAML path. Defaults to
#                                        $ROOT/.run/last/upstream-deployment.yaml
#                                        for ad-hoc invocations.
#
# Reads `terraform output -raw ecr_repository_url` so this only works after
# `make up`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"
NS="default"
NAME="bench-upstream"
HASH_LABEL="bench/spec-hash"

: "${AWS_REGION:?required}"

out="${1:-$ROOT/.run/last/upstream-deployment.yaml}"
mkdir -p "$(dirname "$out")"

REPO_URL=$(cd "$TF_DIR" && terraform output -raw ecr_repository_url 2>/dev/null || true)
if [[ -z "$REPO_URL" ]]; then
  echo "ecr_repository_url terraform output is empty; run 'make up' first" >&2
  exit 1
fi

# Preflight: refuse to deploy if the image hasn't been pushed yet, otherwise
# pods sit in ImagePullBackOff and the user only finds out minutes later.
REPO_NAME="${REPO_URL#*/}"
if ! aws ecr describe-images --region "$AWS_REGION" --repository-name "$REPO_NAME" \
    --image-ids imageTag=latest >/dev/null 2>&1; then
  echo "Image $REPO_URL:latest not found in ECR; run 'make push-upstream' first" >&2
  exit 1
fi

UPSTREAM_IMAGE="$REPO_URL:latest" envsubst < "$ROOT/k8s/upstream/deployment.yaml.tpl" > "$out"

new_hash=$(sha256sum "$out" | cut -c1-12)
# jsonpath needs `/` in label keys escaped as `\.` (e.g. bench/spec-hash → bench\.spec-hash).
jsonpath_label="${HASH_LABEL//\//\\.}"
live_hash=$(kubectl -n "$NS" get deploy "$NAME" \
  -o jsonpath="{.metadata.labels.${jsonpath_label}}" 2>/dev/null || true)

if [[ "$new_hash" == "$live_hash" && -n "$live_hash" ]]; then
  echo "deploy-upstream: spec unchanged (hash=$new_hash), skipping apply"
  exit 0
fi

# Service is small + idempotent; always apply.
kubectl apply -f "$ROOT/k8s/upstream/service.yaml"

# Stamp the hash on the Deployment so future runs can compare.
kubectl apply -f "$out"
kubectl -n "$NS" label deploy "$NAME" "$HASH_LABEL=$new_hash" --overwrite

echo "deploy-upstream: applied (hash=$new_hash, was=${live_hash:-<none>})"
