#!/usr/bin/env bash
# Source before starting OpenCode web UI for the host-isolation (rm -rf) demo.
#   set -a && source scripts/env.demo03.sh && set +a

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

# Fail-closed egress (not the focus of this demo)
export CUBE_OPENCODE_ALLOW_INTERNET=0

# Destructive guest wipe can take a bit; leave headroom.
export CUBE_OPENCODE_TIMEOUT="${CUBE_OPENCODE_TIMEOUT:-180}"

# Single bash call — default session lock is fine.
export CUBE_OPENCODE_LOCK_TIMEOUT="${CUBE_OPENCODE_LOCK_TIMEOUT:-90}"

if ! getent hosts test.cube.app >/dev/null 2>&1; then
  echo "[env.demo03] WARN: test.cube.app does not resolve — sandbox exec will fail."
  echo "[env.demo03]       Fix: sudo bash /usr/local/services/cubetoolbox/scripts/systemd/dns-host-route-up.sh"
fi

echo "[env.demo03] E2B_API_URL=$E2B_API_URL"
echo "[env.demo03] CUBE_TEMPLATE_ID=$CUBE_TEMPLATE_ID"
echo "[env.demo03] SSL_CERT_FILE=${SSL_CERT_FILE:-<unset>}"
echo "[env.demo03] CUBE_OPENCODE_PYTHON=$CUBE_OPENCODE_PYTHON"
echo "[env.demo03] CUBE_OPENCODE_TIMEOUT=$CUBE_OPENCODE_TIMEOUT"
