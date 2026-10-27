#!/usr/bin/env python3
"""Prove ~3 concurrent CubeSandbox MicroVMs are isolated from each other.

Creates three sandboxes in parallel, keeps them alive together, then checks:

1. Distinct sandbox ids / guest boot_ids / hostnames
2. Filesystem: a secret written in A is not readable from B or C
3. Network: CubeVS denies private ranges — peers cannot reach each other's IPs

Exit 0 only when all isolation checks pass.
"""
from __future__ import annotations

import concurrent.futures
import os
import sys
import time

from cubesandbox import Sandbox

TEMPLATE = os.environ["CUBE_TEMPLATE_ID"]
os.environ.setdefault("CUBE_API_URL", os.environ.get("E2B_API_URL", "http://127.0.0.1:3000"))
os.environ.setdefault("E2B_API_URL", os.environ["CUBE_API_URL"])
os.environ.setdefault("E2B_API_KEY", "e2b_000000")

N = int(os.environ.get("CUBE_ISOLATION_WORKERS", "3"))
HOLD_SECONDS = float(os.environ.get("CUBE_ISOLATION_HOLD", "8"))


def create_one(worker: int) -> Sandbox:
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
    print(f"[create] worker={worker} sandbox_id={sb.sandbox_id}")
    return sb


def probe_identity(sb: Sandbox, worker: int, secret: str) -> dict:
    marker = f"/tmp/isolation-worker-{worker}.secret"
    cmd = (
        f"echo {secret!r} > {marker} && chmod 600 {marker} && "
        "printf 'HOSTNAME=%s\\n' \"$(hostname)\"; "
        "printf 'BOOT_ID=%s\\n' \"$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo na)\"; "
        "printf 'IP=%s\\n' \"$(hostname -I 2>/dev/null | awk '{print $1}')\"; "
        "printf 'KERNEL=%s\\n' \"$(uname -r)\"; "
        f"printf 'MARKER=%s\\n' {marker}"
    )
    r = sb.commands.run(cmd, timeout=60)
    out = (r.stdout or "").strip()
    info = {"worker": worker, "sandbox_id": sb.sandbox_id, "secret": secret, "raw": out}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            info[k] = v
    return info


def try_read_peer(sb: Sandbox, peer_worker: int) -> str | None:
    path = f"/tmp/isolation-worker-{peer_worker}.secret"
    r = sb.commands.run(
        f"if [ -r {path} ]; then cat {path}; else echo __MISSING__; fi",
        timeout=30,
    )
    text = (r.stdout or "").strip()
    if text == "__MISSING__" or not text:
        return None
    return text


def try_reach_peer(sb: Sandbox, peer_ip: str) -> str:
    if not peer_ip or peer_ip in ("na",):
        return "skip-no-ip"
    # CubeVS denies private/link-local ranges between sandboxes. Prefer curl/
    # /dev/tcp over ping — ping may be missing from the template (exit 127).
    r = sb.commands.run(
        f"curl -sS -m 2 -o /dev/null -w 'CURL:%{{http_code}}' http://{peer_ip}:80/ 2>/dev/null "
        f"|| echo CURL_FAIL:$?; "
        f"(echo >/dev/tcp/{peer_ip}/22) >/dev/null 2>&1 && echo TCP22:open || echo TCP22:closed",
        timeout=30,
    )
    return (r.stdout or "").strip().replace("\n", " ")

def main() -> int:
    print(f"Creating {N} sandboxes concurrently from template {TEMPLATE}\n")
    sandboxes: list[Sandbox] = []
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=N) as pool:
            futs = [pool.submit(create_one, i + 1) for i in range(N)]
            sandboxes = [f.result() for f in futs]

        print(f"\nAll {N} sandboxes live — holding ~{HOLD_SECONDS}s for overlap evidence")
        # Quick host-side peek at concurrent count if API exposes it
        time.sleep(min(2.0, HOLD_SECONDS))

        identities = []
        for i, sb in enumerate(sandboxes):
            worker = i + 1
            secret = f"iso-w{worker}-{os.urandom(4).hex()}"
            identities.append(probe_identity(sb, worker, secret))

        print("\n--- identities ---")
        for info in identities:
            print(
                f"W{info['worker']}: sandbox_id={info['sandbox_id']} "
                f"boot={info.get('BOOT_ID', '?')} host={info.get('HOSTNAME', '?')} "
                f"ip={info.get('IP', '?')}"
            )

        boot_ids = {info.get("BOOT_ID") for info in identities}
        sandbox_ids = {info["sandbox_id"] for info in identities}
        fs_ok = True
        net_ok = True

        print("\n--- filesystem cross-read (expect MISSING) ---")
        for i, sb in enumerate(sandboxes):
            for j, peer in enumerate(identities):
                if i == j:
                    continue
                leaked = try_read_peer(sb, peer["worker"])
                label = f"W{i + 1} -> W{peer['worker']}"
                if leaked is None:
                    print(f"{label}: MISSING (ok)")
                else:
                    print(f"{label}: LEAKED {leaked!r}")
                    fs_ok = False

        print("\n--- network reachability (expect fail / blocked) ---")
        for i, sb in enumerate(sandboxes):
            for j, peer in enumerate(identities):
                if i == j:
                    continue
                peer_ip = peer.get("IP", "")
                result = try_reach_peer(sb, peer_ip)
                print(f"W{i + 1} -> {peer_ip or '?'}: {result}")
                # Reachability success would break isolation.
                if "CURL:200" in result or "TCP22:open" in result:
                    net_ok = False

        time.sleep(max(0.0, HOLD_SECONDS - 2.0))

        print("\n=== verdict ===")
        distinct_sb = len(sandbox_ids) == N
        distinct_boot = len(boot_ids) == N and None not in boot_ids and "na" not in boot_ids
        print(f"distinct sandbox_id : {distinct_sb} ({sorted(sandbox_ids)})")
        print(f"distinct BOOT_ID    : {distinct_boot} ({sorted(boot_ids)})")
        print(f"filesystem isolated : {fs_ok}")
        print(f"network isolated    : {net_ok}")

        if distinct_sb and distinct_boot and fs_ok and net_ok:
            print("\nISOLATION PASSED")
            return 0
        print("\nISOLATION FAILED")
        return 1
    finally:
        for sb in sandboxes:
            try:
                sb.kill()
            except Exception as exc:  # noqa: BLE001
                print(f"warning: kill failed: {exc}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
