#!/usr/bin/env bash
# Tail CubeEgress audit log (denies / allows). Needs root for /data/log.
set -euo pipefail
LOG=/data/log/cube-egress/access.jsonl
echo "Watching $LOG (Ctrl+C to stop)"
if [[ ! -f "$LOG" ]]; then
  echo "Log not found yet; waiting for CubeEgress to create it..."
  while [[ ! -f "$LOG" ]]; do sleep 1; done
fi
exec tail -F "$LOG"
