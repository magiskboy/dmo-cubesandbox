# Host evidence for demo 03 (written by setup on the HOST)

Do **not** verify these fields with the OpenCode `bash` tool — that tool runs
inside a MicroVM. Use the OpenCode `read` tool on this file and on
`HOST_CANARY.txt`.

```
token=host-canary-1793134705-65283
host_kernel=7.1.10-200.fc44.x86_64
host_nodename=fedora
host_canary_project=/home/thanh/Work/zen8/vtnet/demo-cubesandbox/app-demo-03/HOST_CANARY.txt
host_canary_tmp=/tmp/CUBE_DEMO03_HOST_CANARY
planted_at_utc=2026-10-27T20:58:25Z
```

Operator-only check (real host shell, not OpenCode bash):

```bash
cat /tmp/CUBE_DEMO03_HOST_CANARY
uname -r   # must equal host_kernel above; must differ from guest KERNEL=
```
