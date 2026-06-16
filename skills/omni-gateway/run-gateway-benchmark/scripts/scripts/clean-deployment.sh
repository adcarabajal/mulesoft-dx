#!/usr/bin/env bash
# Tear down per-run workloads while keeping the cluster + observability +
# k6-operator alive. Use between sessions when you want a fresh slate but
# don't want to pay for a full `terraform destroy` + recreate.
#
# Removes:
#   - Flex Helm release (flex-gateway, ns flex)
#   - flex-config ConfigMap
#   - bench-upstream Deployment + service in ns default
#   - All k6 TestRun resources in k6-operator-system
#   - All k6-script-* ConfigMaps
#
# Keeps:
#   - EKS cluster
#   - kube-prometheus-stack, flex-bench-extras, k6-operator (Terraform-owned)
#   - ECR repository
#   - Reports under benchmark/reports/ (use clean-runs.sh for those)
set -euo pipefail

NS_FLEX="flex"
NS_DEFAULT="default"
NS_K6="k6-operator-system"

# Helm release will fail to delete if it's already gone; tolerate that.
echo "==> uninstalling Flex Helm release"
helm uninstall flex-gateway -n "$NS_FLEX" 2>/dev/null || true
kubectl -n "$NS_FLEX" delete configmap flex-config --ignore-not-found

echo "==> deleting upstream Deployment + Service"
kubectl -n "$NS_DEFAULT" delete deploy bench-upstream --ignore-not-found
kubectl -n "$NS_DEFAULT" delete svc upstream --ignore-not-found

echo "==> deleting all k6 TestRuns + script ConfigMaps"
kubectl -n "$NS_K6" delete testrun --all --ignore-not-found
# delete --all on configmaps would nuke the operator's own CMs; filter by name prefix.
mapfile -t cms < <(kubectl -n "$NS_K6" get configmap \
  -o jsonpath='{.items[?(@.metadata.name)].metadata.name}' \
  | tr ' ' '\n' | grep '^k6-script-' || true)
if [[ ${#cms[@]} -gt 0 ]]; then
  kubectl -n "$NS_K6" delete configmap "${cms[@]}" --ignore-not-found
fi

echo "clean-deployment: done. Cluster + observability + k6-operator are still up."
