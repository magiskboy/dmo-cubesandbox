#!/usr/bin/env bash
# Intentionally buggy cleanup — simulates an agent that forgot to set TARGET_DIR.
#
# OpenCode demo uses the *inline* probe in DEMO_PROMPT.md (MicroVM has no host
# workspace mount). This file mirrors that logic for humans / local review.
#
# Intended usage (safe):
#   TARGET_DIR=/tmp/app-demo-03-build bash scripts/buggy-cleanup.sh
#
# Mistaken usage (what the demo forces):
#   TARGET_DIR unset → rm operates on /
#
# Without CubeSandbox this would destroy the host. Inside a MicroVM it only
# affects the ephemeral guest rootfs; the host canaries must survive.
#
# Do NOT run this on the host with TARGET_DIR unset.

set +e
set +u

echo "=== buggy-cleanup start ==="
echo "TARGET_DIR=${TARGET_DIR-<UNSET>}"
echo "HOSTNAME=$(hostname 2>/dev/null || echo unknown)"
echo "BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo na)"
echo "PWD=$(pwd)"
echo "KERNEL=$(uname -r)"

# Guest-only markers (prove the command actually ran inside this VM).
mkdir -p /tmp/demo03-guest
echo "guest-alive-$(date +%s)" > /tmp/demo03-guest/before.txt
ls -la /tmp/demo03-guest/before.txt 2>/dev/null || true

echo ">>> About to run: rm -rf --no-preserve-root \${TARGET_DIR}/"
echo ">>> Expanded path: '${TARGET_DIR}/'"

# Classic agent mistake: variable never exported → expands to "/".
# --no-preserve-root so GNU rm does not refuse '/'. Stderr from /proc|/sys
# noise is discarded so the OpenCode transcript stays readable; damage is
# proven by the post-rm probes below (guest binaries / markers gone).
rm -rf --no-preserve-root "${TARGET_DIR}/" 2>/dev/null
RM_RC=$?
echo "rm exit_code=${RM_RC}"

# After wiping guest "/", most paths are gone. Best-effort leftovers:
echo "=== post-rm probe (guest may be trashed) ==="
if [ -e /tmp/demo03-guest/before.txt ]; then
  echo "GUEST_MARKER_STILL_THERE (unexpected)"
else
  echo "GUEST_MARKER_GONE (expected — wipe hit guest /tmp)"
fi
if command -v ls >/dev/null 2>&1; then
  echo "GUEST_LS_STILL_PRESENT (partial wipe)"
  ls / 2>&1 | head -20 || true
else
  echo "GUEST_LS_GONE (expected — guest /usr|/bin removed)"
fi
echo "=== buggy-cleanup done ==="
exit 0
