#!/usr/bin/env python3
"""Prove accidental ``rm -rf ${TARGET_DIR}/`` (unset → ``/``) cannot wipe the host.

Flow:

1. Plant / refresh host canary files (and record host kernel / ``/etc/passwd``).
2. Create one CubeSandbox MicroVM.
3. Inside the guest, run the same buggy pattern as ``app-demo-03``:
   unset ``TARGET_DIR`` then ``rm -rf --no-preserve-root "${TARGET_DIR}/"``.
4. Re-check host canaries and critical host paths — they must be unchanged.
5. Confirm the command ran in a guest (distinct sandbox id / boot id / kernel).

Exit 0 only when host isolation checks pass.
"""
from __future__ import annotations

import hashlib
import os
import sys
import time
from pathlib import Path

from cubesandbox import Sandbox

TEMPLATE = os.environ["CUBE_TEMPLATE_ID"]
os.environ.setdefault("CUBE_API_URL", os.environ.get("E2B_API_URL", "http://127.0.0.1:3000"))
os.environ.setdefault("E2B_API_URL", os.environ["CUBE_API_URL"])
os.environ.setdefault("E2B_API_KEY", "e2b_000000")

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app-demo-03"
HOST_CANARY_TMP = Path("/tmp/CUBE_DEMO03_HOST_CANARY")
HOST_CANARY_PROJ = APP / "HOST_CANARY.txt"


def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def plant_host_canaries() -> dict:
    token = f"host-canary-{int(time.time())}-{os.urandom(4).hex()}"
    host_uname = os.uname()
    HOST_CANARY_TMP.write_text(token + "\n", encoding="utf-8")
    HOST_CANARY_PROJ.write_text(
        "HOST_CANARY_DEMO03\n"
        f"token={token}\n"
        f"path={HOST_CANARY_PROJ}\n"
        f"also_on_host={HOST_CANARY_TMP}\n\n"
        "This file lives on the HOST under app-demo-03/.\n",
        encoding="utf-8",
    )
    evidence = APP / "HOST_EVIDENCE.md"
    evidence.write_text(
        "# Host evidence for demo 03 (written by verify on the HOST)\n\n"
        "```\n"
        f"token={token}\n"
        f"host_kernel={host_uname.release}\n"
        f"host_nodename={host_uname.nodename}\n"
        f"host_canary_project={HOST_CANARY_PROJ}\n"
        f"host_canary_tmp={HOST_CANARY_TMP}\n"
        f"planted_at_utc={time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n"
        "```\n",
        encoding="utf-8",
    )
    passwd_hash = sha256_file(Path("/etc/passwd"))
    snap = {
        "token": token,
        "tmp_path": str(HOST_CANARY_TMP),
        "tmp_hash": sha256_file(HOST_CANARY_TMP),
        "proj_path": str(HOST_CANARY_PROJ),
        "proj_hash": sha256_file(HOST_CANARY_PROJ),
        "passwd_hash": passwd_hash,
        "host_kernel": host_uname.release,
        "host_nodename": host_uname.nodename,
    }
    print("--- host canaries (before) ---")
    for k in ("tmp_path", "tmp_hash", "proj_path", "proj_hash", "passwd_hash", "host_kernel"):
        print(f"{k}={snap[k]}")
    return snap


def check_host_intact(before: dict) -> bool:
    ok = True
    print("\n--- host canaries (after) ---")
    for label, path, expected_hash in (
        ("tmp", HOST_CANARY_TMP, before["tmp_hash"]),
        ("proj", HOST_CANARY_PROJ, before["proj_hash"]),
        ("passwd", Path("/etc/passwd"), before["passwd_hash"]),
    ):
        now = sha256_file(path)
        status = "OK" if now == expected_hash and now is not None else "MISSING_OR_CHANGED"
        print(f"{label}: {status} path={path} hash={now}")
        if status != "OK":
            ok = False

    # Token content check (human-readable evidence)
    try:
        body = HOST_CANARY_TMP.read_text(encoding="utf-8").strip()
        if body != before["token"]:
            print(f"tmp token mismatch: got={body!r} expected={before['token']!r}")
            ok = False
        else:
            print(f"tmp token intact: {body}")
    except OSError as exc:
        print(f"tmp token unreadable: {exc}")
        ok = False

    return ok


BUGGY_CMD = r"""
set +e
set +u
unset TARGET_DIR
echo "TARGET_DIR=${TARGET_DIR-<UNSET>}"
echo "HOSTNAME=$(hostname 2>/dev/null || echo unknown)"
echo "BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo na)"
echo "KERNEL=$(uname -r)"
mkdir -p /tmp/demo03-guest
echo guest-before > /tmp/demo03-guest/before.txt
echo ">>> rm -rf --no-preserve-root ${TARGET_DIR}/  (expands to '/')"
# Discard /proc|/sys permission noise; prove wipe via probes below.
rm -rf --no-preserve-root "${TARGET_DIR}/" 2>/dev/null
echo "rm_exit=$?"
if [ -e /tmp/demo03-guest/before.txt ]; then echo GUEST_MARKER_STILL_THERE; else echo GUEST_MARKER_GONE; fi
if command -v ls >/dev/null 2>&1; then echo GUEST_LS_STILL_PRESENT; else echo GUEST_LS_GONE; fi
"""


def parse_kv(stdout: str) -> dict:
    info: dict[str, str] = {}
    for line in (stdout or "").splitlines():
        if "=" in line and not line.startswith(">>>"):
            k, _, v = line.partition("=")
            k = k.strip()
            if k in {"TARGET_DIR", "HOSTNAME", "BOOT_ID", "KERNEL", "rm_exit"} or k.startswith("GUEST"):
                info[k] = v.strip()
    return info


def main() -> int:
    before = plant_host_canaries()
    print(f"\nCreating sandbox from template {TEMPLATE}")
    sb = Sandbox.create(
        template=TEMPLATE,
        allow_internet_access=False,
        network={
            "allow_out": [
                "registry.npmjs.org",
                "pypi.org",
                "files.pythonhosted.org",
            ]
        },
    )
    try:
        print(f"sandbox_id={sb.sandbox_id}")
        print("\n--- running buggy rm inside MicroVM ---")
        result = sb.commands.run(BUGGY_CMD, timeout=120)
        stdout = result.stdout or ""
        stderr = result.stderr or ""
        print(stdout)
        if stderr.strip():
            print("--- stderr ---")
            print(stderr)
        guest = parse_kv(stdout)
        guest_kernel = guest.get("KERNEL", "")
        guest_boot = guest.get("BOOT_ID", "")
        wipe_hit = ("GUEST_MARKER_GONE" in stdout) or ("GUEST_LS_GONE" in stdout)

        host_ok = check_host_intact(before)

        print("\n=== verdict ===")
        distinct_kernel = bool(guest_kernel) and guest_kernel != before["host_kernel"]
        has_boot = bool(guest_boot) and guest_boot not in {"", "na"}
        print(f"sandbox_id present   : {bool(sb.sandbox_id)} ({sb.sandbox_id})")
        print(f"guest BOOT_ID        : {has_boot} ({guest_boot or '?'})")
        print(f"guest KERNEL != host : {distinct_kernel} (guest={guest_kernel or '?'} host={before['host_kernel']})")
        print(f"guest wipe evidence  : {wipe_hit}")
        print(f"host canaries intact : {host_ok}")

        if host_ok and distinct_kernel and has_boot and wipe_hit:
            print("\nHOST ISOLATION PASSED")
            return 0
        print("\nHOST ISOLATION FAILED")
        return 1
    finally:
        try:
            sb.kill()
        except Exception as exc:  # noqa: BLE001
            print(f"warning: kill failed: {exc}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
