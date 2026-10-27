#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT/opencode-plugin-sandbox"
APP="$ROOT/app-demo-02"

echo "==> Ensure Python venv + SDK (reuse demo-app setup if present)"
if [[ ! -x "$HOME/.venvs/cube/bin/python" ]]; then
  python3 -m venv "$HOME/.venvs/cube"
  "$HOME/.venvs/cube/bin/pip" install -U pip
  "$HOME/.venvs/cube/bin/pip" install e2b-code-interpreter
fi
# Prefer cubesandbox if available (same as verify scripts)
"$HOME/.venvs/cube/bin/pip" install -q cubesandbox 2>/dev/null || true

echo "==> Install CubeSandbox OpenCode plugin into app-demo-02"
mkdir -p "$APP"
cd "$APP"
"$PLUGIN_DIR/plugin/install.sh" --dir "$APP/.opencode/plugin"

if [[ ! -e "$APP/exec_backend.py" ]]; then
  ln -sfn "$PLUGIN_DIR/exec_backend.py" "$APP/exec_backend.py"
fi

echo "==> Done. Next:"
echo "  1. export CUBE_TEMPLATE_ID=...  (from cubemastercli tpl list)"
echo "  2. set -a && source $ROOT/scripts/env.demo02.sh && set +a"
echo "  3. cd $APP && opencode web --model opencode/nemotron-3.5-lightning-free --port 4097"
echo "  4. Paste $APP/DEMO_PROMPT.md into the chat"
echo "  Optional SDK check: python3 $ROOT/scripts/08-verify-isolation.py"
