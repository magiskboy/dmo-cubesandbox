#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT/opencode-plugin-sandbox"
APP="$ROOT/app-demo-03"
CANARY_HOST="/tmp/CUBE_DEMO03_HOST_CANARY"
HOST_KERNEL="$(uname -r)"
HOST_NODE="$(uname -n)"

echo "==> Ensure Python venv + SDK (reuse prior demo setup if present)"
if [[ ! -x "$HOME/.venvs/cube/bin/python" ]]; then
  python3 -m venv "$HOME/.venvs/cube"
  "$HOME/.venvs/cube/bin/pip" install -U pip
  "$HOME/.venvs/cube/bin/pip" install e2b-code-interpreter
fi
"$HOME/.venvs/cube/bin/pip" install -q cubesandbox 2>/dev/null || true

echo "==> Install CubeSandbox OpenCode plugin into app-demo-03"
mkdir -p "$APP/scripts"
chmod +x "$APP/scripts/buggy-cleanup.sh" 2>/dev/null || true
cd "$APP"
"$PLUGIN_DIR/plugin/install.sh" --dir "$APP/.opencode/plugin"

if [[ ! -e "$APP/exec_backend.py" ]]; then
  ln -sfn "$PLUGIN_DIR/exec_backend.py" "$APP/exec_backend.py"
fi

echo "==> Plant host canaries + evidence (readable via OpenCode read tool)"
TOKEN="host-canary-$(date +%s)-$(head -c 4 /dev/urandom | xxd -p 2>/dev/null || echo $$)"
printf '%s\n' "$TOKEN" > "$CANARY_HOST"
chmod 644 "$CANARY_HOST"

cat > "$APP/HOST_CANARY.txt" <<EOF
HOST_CANARY_DEMO03
token=${TOKEN}
path=${APP}/HOST_CANARY.txt
also_on_host=${CANARY_HOST}

This file lives on the HOST under app-demo-03/.
After the MicroVM rm -rf /, OpenCode must still open this file with the read
tool (not bash). If bash cannot see it, that is expected — bash is sandboxed.
EOF

cat > "$APP/HOST_EVIDENCE.md" <<EOF
# Host evidence for demo 03 (written by setup on the HOST)

Do **not** verify these fields with the OpenCode \`bash\` tool — that tool runs
inside a MicroVM. Use the OpenCode \`read\` tool on this file and on
\`HOST_CANARY.txt\`.

\`\`\`
token=${TOKEN}
host_kernel=${HOST_KERNEL}
host_nodename=${HOST_NODE}
host_canary_project=${APP}/HOST_CANARY.txt
host_canary_tmp=${CANARY_HOST}
planted_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
\`\`\`

Operator-only check (real host shell, not OpenCode bash):

\`\`\`bash
cat ${CANARY_HOST}
uname -r   # must equal host_kernel above; must differ from guest KERNEL=
\`\`\`
EOF

echo "    token=${TOKEN}"
echo "    host_kernel=${HOST_KERNEL}"
echo "    wrote ${APP}/HOST_CANARY.txt"
echo "    wrote ${APP}/HOST_EVIDENCE.md"
echo "    wrote ${CANARY_HOST}"

echo "==> Done. Next:"
echo "  1. export CUBE_TEMPLATE_ID=...  (from cubemastercli tpl list)"
echo "  2. set -a && source $ROOT/scripts/env.demo03.sh && set +a"
echo "  3. cd $APP && opencode web --model opencode/nemotron-3.5-lightning-free --port 4098"
echo "  4. Paste $APP/DEMO_PROMPT.md into the chat"
echo "  Optional SDK check: python3 $ROOT/scripts/10-verify-host-isolation.py"
echo "  After demo, agent must use read tool on HOST_CANARY.txt / HOST_EVIDENCE.md"
echo "  Operator shell: cat $CANARY_HOST && uname -r"
