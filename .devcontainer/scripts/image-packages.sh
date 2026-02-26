#!/usr/bin/env bash
# image-packages.sh — single source of truth for packages added to all images.
#
# Both setup-layers.sh (STM32) and build-qemu.sh (QEMU) source this file after
# they have set LOCAL_CONF.  Adding a package here automatically applies it to
# every build target.
#
# Usage (inside a build script, after LOCAL_CONF is set):
#   source "$(dirname "${BASH_SOURCE[0]}")/image-packages.sh"
#
# Optional feature flags (set in environment before calling make/build script):
#   MYIR_ENABLE_BT_WIFI=true   — include Bluetooth/WiFi stack (default: false)
#                                 Adds: bluez5 wpa-supplicant wireless-tools
#                                       linux-firmware-addons-bcm43xx
#                                       bluetooth-suspend
# ---------------------------------------------------------------------------

[[ -z "${LOCAL_CONF:-}" ]] && { echo "[image-packages] ERROR: LOCAL_CONF is not set." >&2; exit 1; }

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
    echo "[image-packages] BT/WiFi stack ENABLED (MYIR_ENABLE_BT_WIFI=true)"
    IMAGE_PACKAGES+=(
        bluez5
        bluez5-noinst-tools
        wpa-supplicant
        wireless-tools
        linux-firmware-addons-bcm43xx
        bluetooth-suspend
    )
else
    echo "[image-packages] BT/WiFi stack disabled (set MYIR_ENABLE_BT_WIFI=true to enable)"
fi

echo "IMAGE_INSTALL:append = \" ${IMAGE_PACKAGES[*]}\"" >> "${LOCAL_CONF}"
