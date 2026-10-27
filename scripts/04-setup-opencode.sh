#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT/opencode-plugin-sandbox"

echo "==> Python venv + e2b SDK"
python3 -m venv "$HOME/.venvs/cube"
"$HOME/.venvs/cube/bin/pip" install -U pip
"$HOME/.venvs/cube/bin/pip" install e2b-code-interpreter

echo "==> Install CubeSandbox OpenCode plugin into demo-app"
cd "$ROOT/demo-app"
"$PLUGIN_DIR/plugin/install.sh" --dir "$ROOT/demo-app/.opencode/plugin"

# ensure backend is reachable next to plugin (install.sh usually handles this)
if [[ ! -e "$ROOT/demo-app/exec_backend.py" ]]; then
  ln -sfn "$PLUGIN_DIR/exec_backend.py" "$ROOT/demo-app/exec_backend.py"
fi

echo "==> Make mkcert CA readable (if owned by root)"
if [[ -r /root/.local/share/mkcert/rootCA.pem ]] && [[ ! -r "$HOME/.local/share/mkcert/rootCA.pem" ]]; then
  mkdir -p "$HOME/.local/share/mkcert"
  cp /root/.local/share/mkcert/rootCA.pem "$HOME/.local/share/mkcert/rootCA.pem" 2>/dev/null \
    || echo "Run: sudo cp /root/.local/share/mkcert/rootCA.pem $HOME/.local/share/mkcert/rootCA.pem"
fi

echo "==> npm install local malicious package"
cd "$ROOT/demo-app"
npm install

echo "==> Done. Next:"
echo "  1. export CUBE_TEMPLATE_ID=...  (from cubemastercli tpl list)"
echo "  2. set -a && source $ROOT/scripts/env.demo.sh && set +a"
echo "  3. cd $ROOT/demo-app && opencode web --model opencode/nemotron-3.5-lightning-free"
