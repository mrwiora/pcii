#!/usr/bin/env bash
# image-policy.sh — single source of truth for ALL image policy.
#
# Both setup-layers.sh (STM32MP) and build-qemu.sh (QEMU) source this file
# after they have set LOCAL_CONF.  Every policy decision made here is
# automatically applied to every build target — no target can diverge.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ RULE: If a setting must affect the whole product, it belongs here.      │
# │       Never write IMAGE_FEATURES, APPEND, or IMAGE_INSTALL directly     │
# │       inside a build script.                                            │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Usage (inside a build script, after LOCAL_CONF is set):
#   source "$(dirname "${BASH_SOURCE[0]}")/image-policy.sh"
#
# Optional feature flags (set in environment before calling make/build):
#   MYIR_ENABLE_BT_WIFI=true   — include Bluetooth/WiFi stack (default: false)
# ---------------------------------------------------------------------------

[[ -z "${LOCAL_CONF:-}" ]] && { echo "[image-policy] ERROR: LOCAL_CONF is not set." >&2; exit 1; }

# ── Image features ───────────────────────────────────────────────────────────
#
# read-only-rootfs  — Yocto creates /var/volatile symlinks at image-creation
#                     time so that /var/log, /var/lock, /var/run, /var/spool,
#                     and /var/tmp are backed by the volatile tmpfs, not the
#                     read-only disk.  Also suppresses deferred postinst scripts
#                     that would try to write to the rootfs at first boot.
echo 'IMAGE_FEATURES:append = " read-only-rootfs"' >> "${LOCAL_CONF}"

# ── Kernel command line (QEMU) ────────────────────────────────────────────────
#
# APPEND is the variable that runqemu appends to the QEMU kernel cmdline.
# For STM32MP hardware, the cmdline is owned by UBOOT_EXTLINUX_KERNEL_ARGS in
# conf/machine/include/st-machine-extlinux-config-stm32mp.inc (already set to
# "rootwait ro …").  Setting APPEND here is a no-op for that boot path.
echo 'APPEND:append = " ro"' >> "${LOCAL_CONF}"

# ── Core packages installed into every image ─────────────────────────────────
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

# ── Optional: Bluetooth / WiFi stack ─────────────────────────────────────────
# Disabled by default because it adds significant build time and requires
# Murata CYW43430/43439 hardware (WiFi) and brcmfmac Bluetooth to be present.
#
# Enable with:   MYIR_ENABLE_BT_WIFI=true make build-stm32
#           or:  MYIR_ENABLE_BT_WIFI=true make build-qemu
#           or:  export MYIR_ENABLE_BT_WIFI=true  (persists for the session)
if [[ "${MYIR_ENABLE_BT_WIFI:-false}" == "true" ]]; then
    echo "[image-policy] BT/WiFi stack ENABLED (MYIR_ENABLE_BT_WIFI=true)"
    IMAGE_PACKAGES+=(
        bluez5
        bluez5-noinst-tools
        wpa-supplicant
        wireless-tools
        linux-firmware-addons-bcm43xx
        bluetooth-suspend
    )
else
    echo "[image-policy] BT/WiFi stack disabled (set MYIR_ENABLE_BT_WIFI=true to enable)"
fi

echo "IMAGE_INSTALL:append = \" ${IMAGE_PACKAGES[*]}\"" >> "${LOCAL_CONF}"
