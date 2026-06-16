#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?required}"
: "${CLUSTER_NAME:?required}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/terraform"

repo_url="$(terraform output -raw ecr_repository_url)"
registry="$(terraform output -raw ecr_registry)"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$registry"

cd "$ROOT/docker/upstream"
tag="${UPSTREAM_TAG:-latest}"
# EKS nodes are amd64; building on an arm64 host (Apple Silicon) without
# --platform produces an arm64-only image that fails on the cluster with
# "no match for platform in manifest". buildx targets the node arch and
# pushes in one step. Override UPSTREAM_PLATFORM for arm64 node pools.
platform="${UPSTREAM_PLATFORM:-linux/amd64}"
docker buildx build --platform "$platform" -t "$repo_url:$tag" --push .
echo "Pushed $repo_url:$tag ($platform)"
