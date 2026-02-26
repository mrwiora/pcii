#!/usr/bin/env bash
# image-packages.sh — single source of truth for packages added to all images.
#
# Both setup-layers.sh (STM32) and build-qemu.sh (QEMU) source this file after
# they have set LOCAL_CONF.  Adding a package here automatically applies it to
# every build target.
#
# Usage (inside a build script, after LOCAL_CONF is set):
#   source "$(dirname "${BASH_SOURCE[0]}")/image-packages.sh"
# ---------------------------------------------------------------------------

[[ -z "${LOCAL_CONF:-}" ]] && { echo "[image-packages] ERROR: LOCAL_CONF is not set." >&2; exit 1; }

# ── Packages installed into every image ──────────────────────────────────────
#
# nftables           — nft binary (/usr/sbin/nft)
# nftables-config    — /etc/nftables.conf + /etc/init.d/nftables  (separate
#                      recipe so editing the ruleset only rebuilds ~3 tasks,
#                      not the full nftables package and all its dependents)
# kernel-modules     — all kernel modules (required for nft kernel modules)
#
# ADD NEW PACKAGES BELOW — they will be picked up by all builds automatically.
IMAGE_PACKAGES=(
    nftables
    nftables-config
    kernel-modules
)

echo "IMAGE_INSTALL:append = \" ${IMAGE_PACKAGES[*]}\"" >> "${LOCAL_CONF}"
