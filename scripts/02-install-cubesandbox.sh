#!/usr/bin/env bash
# Bare-metal one-click install (native /dev/kvm present — no PVM kernel).
set -euo pipefail

export MIRROR="${MIRROR:-cn}"
# Host LAN is 192.168.1.0/24 — default cubevs 192.168.0.0/18 conflicts.
export CUBE_SANDBOX_NETWORK_CIDR="${CUBE_SANDBOX_NETWORK_CIDR:-10.100.0.0/18}"
# Prefer GitHub raw if CNB is slow; default follows official bare-metal guide.
INSTALL_URL="${CUBE_ONLINE_INSTALL_URL:-https://cnb.cool/CubeSandbox/CubeSandbox/-/git/raw/master/deploy/one-click/online-install.sh}"

echo "==> Preflight"
ls -la /dev/kvm
df -Th /data/cubelet
systemctl is-active docker
free -h | head -2
echo "CUBE_SANDBOX_NETWORK_CIDR=${CUBE_SANDBOX_NETWORK_CIDR}"

echo "==> Running online-install (MIRROR=${MIRROR})"
curl -fsSL "$INSTALL_URL" | bash -s -- "$@"
echo "[wrapper] online-install exit=$?"

echo "==> Smoke / status"
systemctl --no-pager --type=target | grep -i cube || true
systemctl --no-pager status cube-sandbox-control.target || true
curl -fsS http://127.0.0.1:3000/health || curl -fsS http://127.0.0.1:3000/ || true

echo "==> Install finished"
