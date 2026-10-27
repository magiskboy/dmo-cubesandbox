#!/usr/bin/env bash
# Source before starting OpenCode web UI for the CubeSandbox egress demo.
#   set -a && source scripts/env.demo.sh && set +a

export CUBE_TEMPLATE_ID="${CUBE_TEMPLATE_ID:-tpl-18351e7a21ba49938754eeac}"

export E2B_API_URL="${E2B_API_URL:-http://127.0.0.1:3000}"
export CUBE_API_URL="${CUBE_API_URL:-$E2B_API_URL}"
export E2B_API_KEY="${E2B_API_KEY:-e2b_000000}"

if [[ -z "${SSL_CERT_FILE:-}" ]]; then
  for cand in \
    "$HOME/.local/share/mkcert/rootCA.pem" \
    /root/.local/share/mkcert/rootCA.pem
  do
    if [[ -r "$cand" ]]; then
      export SSL_CERT_FILE="$cand"
      break
    fi
  done
fi

export CUBE_OPENCODE_PYTHON="${CUBE_OPENCODE_PYTHON:-$HOME/.venvs/cube/bin/python}"

# Fail-closed egress: only allowlisted registries (httpbin.org NOT allowed)
export CUBE_OPENCODE_ALLOW_INTERNET=0

echo "[env.demo] E2B_API_URL=$E2B_API_URL"
echo "[env.demo] CUBE_TEMPLATE_ID=$CUBE_TEMPLATE_ID"
echo "[env.demo] SSL_CERT_FILE=${SSL_CERT_FILE:-<unset>}"
echo "[env.demo] CUBE_OPENCODE_PYTHON=$CUBE_OPENCODE_PYTHON"
echo "[env.demo] CUBE_OPENCODE_ALLOW_INTERNET=$CUBE_OPENCODE_ALLOW_INTERNET"
