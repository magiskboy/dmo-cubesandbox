#!/usr/bin/env bash
# Source before starting OpenCode web UI for the concurrent-isolation demo.
#   set -a && source scripts/env.demo02.sh && set +a

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

# Fail-closed egress (same posture as demo 1; not the focus of this demo)
export CUBE_OPENCODE_ALLOW_INTERNET=0

# Critical for demo 02: allow same-session bash calls to create MicroVMs in
# parallel instead of waiting on the session lock (default 90s).
export CUBE_OPENCODE_LOCK_TIMEOUT=0

# Isolation probes sleep ~15s; keep headroom for create + overlap.
export CUBE_OPENCODE_TIMEOUT="${CUBE_OPENCODE_TIMEOUT:-180}"

if ! getent hosts test.cube.app >/dev/null 2>&1; then
  echo "[env.demo02] WARN: test.cube.app does not resolve — sandbox exec will fail."
  echo "[env.demo02]       Fix: sudo bash /usr/local/services/cubetoolbox/scripts/systemd/dns-host-route-up.sh"
fi

echo "[env.demo02] E2B_API_URL=$E2B_API_URL"
echo "[env.demo02] CUBE_TEMPLATE_ID=$CUBE_TEMPLATE_ID"
echo "[env.demo02] SSL_CERT_FILE=${SSL_CERT_FILE:-<unset>}"
echo "[env.demo02] CUBE_OPENCODE_PYTHON=$CUBE_OPENCODE_PYTHON"
echo "[env.demo02] CUBE_OPENCODE_LOCK_TIMEOUT=$CUBE_OPENCODE_LOCK_TIMEOUT"
echo "[env.demo02] CUBE_OPENCODE_TIMEOUT=$CUBE_OPENCODE_TIMEOUT"
