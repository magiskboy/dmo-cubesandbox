# Demo 03 — host isolation against accidental `rm -rf /`

You are demonstrating that CubeSandbox isolates shell execution from the host.
Simulate an agent mistake: a cleanup uses `rm -rf ${TARGET_DIR}/` but
`TARGET_DIR` was **never set**, so the path expands to `/`.

## Critical tool split (read this first)

| Tool | Where it runs | Use for |
|---|---|---|
| `bash` | **MicroVM only** (no host filesystem) | The destructive cleanup probe |
| `read` | **Host project files** | Proving host canaries survived |

**Never** use `bash` to check host canaries, host `uname -r`, or paths like
`/tmp/CUBE_DEMO03_HOST_CANARY`. Those commands run in a **new empty MicroVM**,
so the files will look “missing” and kernels will look “the same” even when the
host is fine. That is a false FAIL.

## Goal

1. Run the buggy cleanup via **one** `bash` call (`TARGET_DIR` unset).
2. Prove the host survived via the **`read` tool** (not bash).

## Step 1 — destructive probe (exactly one bash tool call)

Run this **verbatim**. Do not set `TARGET_DIR`. Do not “fix” the bug.

```bash
set +e
set +u
unset TARGET_DIR
echo "=== buggy-cleanup start ==="
echo "TARGET_DIR=${TARGET_DIR-<UNSET>}"
echo "HOSTNAME=$(hostname 2>/dev/null || echo unknown)"
echo "BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo na)"
echo "PWD=$(pwd)"
echo "KERNEL=$(uname -r)"
mkdir -p /tmp/demo03-guest
echo "guest-alive-$(date +%s)" > /tmp/demo03-guest/before.txt
echo ">>> About to run: rm -rf --no-preserve-root \${TARGET_DIR}/"
echo ">>> Expanded path: '${TARGET_DIR}/'"
rm -rf --no-preserve-root "${TARGET_DIR}/" 2>/dev/null
echo "rm exit_code=$?"
echo "=== post-rm probe (guest may be trashed) ==="
if [ -e /tmp/demo03-guest/before.txt ]; then
  echo "GUEST_MARKER_STILL_THERE (unexpected)"
else
  echo "GUEST_MARKER_GONE (expected — wipe hit guest /tmp)"
fi
if command -v ls >/dev/null 2>&1; then
  echo "GUEST_LS_STILL_PRESENT (partial wipe)"
else
  echo "GUEST_LS_GONE (expected — guest /usr|/bin removed)"
fi
echo "=== buggy-cleanup done ==="
```

## Step 2 — host proof (use `read` tool only — no bash)

After Step 1 finishes, call the **`read` tool** on these project files (host):

1. `HOST_CANARY.txt`
2. `HOST_EVIDENCE.md`

Expected:

- `HOST_CANARY.txt` still contains the line `HOST_CANARY_DEMO03` and the
  `token=` value from setup.
- `HOST_EVIDENCE.md` lists `host_kernel=` and the same `token=`.

Compare:

- Guest `KERNEL=` from Step 1 bash output
- `host_kernel=` from `HOST_EVIDENCE.md` (via **read**, not bash)

They **must differ**. Do **not** run `uname -r` via bash for the host side.

Optional (operator terminal only, not you): `cat /tmp/CUBE_DEMO03_HOST_CANARY`

## Verdict

Conclude **HOST ISOLATION PASSED** only if all of these hold:

1. Step 1 shows `TARGET_DIR=<UNSET>`, wipe evidence (`GUEST_MARKER_GONE` and/or
   `GUEST_LS_GONE`), and a `[cubesandbox-exec] sandbox_id=...` / guest `BOOT_ID`.
2. Step 2 **`read`** still returns `HOST_CANARY.txt` + `HOST_EVIDENCE.md` with
   the expected token.
3. Guest `KERNEL` ≠ `host_kernel` from `HOST_EVIDENCE.md`.

Conclude **HOST ISOLATION FAILED** only if:

- Step 1 clearly ran on the host (no `sandbox_id` / no guest identity), **or**
- Step 2 **`read`** cannot open `HOST_CANARY.txt` / content was destroyed.

Do **not** FAIL merely because bash cannot see `/tmp/CUBE_DEMO03_HOST_CANARY`
or because a second bash `uname -r` matches the guest kernel — those checks are
invalid under CubeSandbox.

Do not install packages. Do not fix the unset variable.
