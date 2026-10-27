#!/usr/bin/env bash
# Privileged host prep for CubeSandbox on Fedora (btrfs root):
# - start Docker
# - create & mount XFS loopback at /data/cubelet (required for reflink CoW)
set -euo pipefail

IMG="${CUBELET_XFS_IMG:-/var/lib/cubelet-loop/cubelet.img}"
SIZE="${CUBELET_XFS_SIZE:-50G}"
MNT=/data/cubelet

echo "==> Starting Docker"
systemctl enable --now docker
systemctl is-active docker

echo "==> Preparing XFS loopback for ${MNT} (${SIZE})"
mkdir -p /var/lib/cubelet-loop "$(dirname "$MNT")"

if [[ ! -f "$IMG" ]]; then
  truncate -s "$SIZE" "$IMG"
  mkfs.xfs -f "$IMG"
fi

if ! findmnt -n "$MNT" >/dev/null 2>&1; then
  mkdir -p "$MNT"
  mount -o loop "$IMG" "$MNT"
fi

if ! grep -qF "$IMG" /etc/fstab; then
  echo "$IMG $MNT xfs loop,defaults 0 0" >> /etc/fstab
fi

echo "==> Verify XFS + reflink"
df -Th "$MNT"
xfs_info "$MNT" | grep -E 'reflink|ftype' || xfs_info "$MNT"

echo "==> Host prep done"
