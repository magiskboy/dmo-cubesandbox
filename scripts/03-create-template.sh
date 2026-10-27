#!/usr/bin/env bash
# Create the code-interpreter template and print CUBE_TEMPLATE_ID.
set -euo pipefail

MIRROR="${MIRROR:-cn}"
if [[ "$MIRROR" == "cn" ]]; then
  IMAGE="cube-sandbox-cn.tencentcloudcr.com/cube-sandbox/sandbox-code:latest"
else
  IMAGE="cube-sandbox-int.tencentcloudcr.com/cube-sandbox/sandbox-code:latest"
fi

export PATH="/usr/local/services/cubetoolbox/CubeMaster:${PATH}:/usr/local/bin"

echo "==> Creating template from ${IMAGE}"
# cubemastercli prints job / template ids; capture full output.
OUT=$(cubemastercli tpl create-from-image \
  --image "$IMAGE" \
  --writable-layer-size 1G \
  --expose-port 49999 \
  --expose-port 49983 \
  --probe 49999 2>&1 | tee /dev/stderr)

JOB_ID=$(echo "$OUT" | grep -Eo 'job[_-]?id[=: ]+[A-Za-z0-9_-]+' -i | head -1 | awk '{print $NF}' | tr -d '="')
if [[ -z "${JOB_ID}" ]]; then
  JOB_ID=$(echo "$OUT" | grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)
fi

if [[ -n "${JOB_ID}" ]]; then
  echo "==> Watching job ${JOB_ID}"
  cubemastercli tpl watch --job-id "$JOB_ID" || true
fi

echo "==> Template list"
cubemastercli tpl list

echo
echo "Export the READY template id:"
echo "  export CUBE_TEMPLATE_ID=<template_id>"
