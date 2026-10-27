# Demo 02 — concurrent MicroVM isolation

You are demonstrating that CubeSandbox gives each `bash` call its own isolated
MicroVM. Do **exactly** the following.

## Goal

Issue **three** `bash` tool calls **in the same turn, concurrently** (do not wait
for one to finish before starting the next). Use workers `1`, `2`, and `3`.

Each call must run this probe (replace `WORKER_ID` with `1`, `2`, or `3`):

```bash
WORKER=WORKER_ID
SECRET="iso-w${WORKER}-$(head -c 8 /dev/urandom | xxd -p 2>/dev/null || od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
MARKER="/tmp/isolation-worker-${WORKER}.secret"
echo "$SECRET" > "$MARKER"
chmod 600 "$MARKER"
HOSTNAME=$(hostname 2>/dev/null || echo unknown)
BOOT=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo na)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
KERNEL=$(uname -r)
# Stay alive so the other two MicroVMs overlap in time
sleep 15
SEEN=$(ls -1 /tmp/isolation-worker-*.secret 2>/dev/null | tr '\n' ' ')
PEER_LEAK=""
for other in 1 2 3; do
  if [ "$other" != "$WORKER" ]; then
    other_file="/tmp/isolation-worker-${other}.secret"
    if [ -r "$other_file" ]; then
      PEER_LEAK="${PEER_LEAK} LEAKED_FROM_W${other}=$(cat "$other_file")"
    fi
  fi
done
printf '=== isolation-worker-%s ===\n' "$WORKER"
printf 'WORKER=%s\nHOSTNAME=%s\nBOOT_ID=%s\nIP=%s\nKERNEL=%s\nSECRET=%s\nTMP_SECRETS=%s\nPEER_LEAK=%s\n' \
  "$WORKER" "$HOSTNAME" "$BOOT" "$IP" "$KERNEL" "$SECRET" "$SEEN" "${PEER_LEAK:-none}"
```

## After all three finish

Summarize in a short table:

1. Did you get **three** distinct `BOOT_ID` values? (guest hostname may look similar — that is OK)
2. For each worker, does `TMP_SECRETS` list **only** its own marker?
3. Is every `PEER_LEAK=none`?
4. Paste any `[cubesandbox-exec] sandbox_id=...` lines from tool stderr if present — they must be three different ids.

Notes:

- Guest `IP` may look identical across workers (CubeVS often uses the same link-local on each private TAP). Do **not** treat matching IPs as a failure.
- Isolation is proven by distinct MicroVM `BOOT_ID` / `sandbox_id` plus the filesystem checks above.

If any peer secret leaked, or all three share one `BOOT_ID`, say isolation **FAILED**. Otherwise conclude isolation **PASSED**.

Do not install packages. Do not skip the `sleep`. Do not serialize the three bash calls.
