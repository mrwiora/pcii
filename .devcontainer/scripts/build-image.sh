#!/usr/bin/env bash
# build-image.sh
#
# Builds the complete image set for the MYC-YF135-8E512D-100-I (myd-yf13x).
#
# Build order:
#   1.  TF-A  (BL2 – first-stage bootloader / FSBL)
#   2.  OP-TEE OS  (secure OS, bundled into the FIP)
#   3.  FIP bundle  (TF-A + OP-TEE + U-Boot BL33)
#   4.  Linux kernel
#   5.  st-image-bootfs  (bootfs partition: kernel + dtb + extlinux)
#   6.  st-image-vendorfs  (vendor GPU / Wi-Fi / BT firmware)
#   7.  st-image-userfs  (user-space utilities, MYIR tools)
#
# Output SD-card layout (via wic/sdcard-myd-yf13x-optee-vendorfs-1GB.wks.in):
#   GPT | fsbl1 | fsbl2 | metadata×2 | fip-a | fip-b | uenv | bootfs |
#         vendorfs | rootfs | userfs |
# ---------------------------------------------------------------------------
set -euo pipefail

WORKDIR=/workdir
BUILD_DIR="${WORKDIR}/build"
POKY_DIR="${WORKDIR}/poky"

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'
log()     { echo -e "\n${GREEN}[build]${RESET} ${BOLD}$*${RESET}"; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
            echo -e "${CYAN} $*${RESET}"; \
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
fail()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -d "${POKY_DIR}" ]]    || fail "poky not found at ${POKY_DIR}. Run setup-layers.sh first."
[[ -d "${BUILD_DIR}" ]]   || fail "build dir missing. Run setup-layers.sh first."

# Prevent accidental root builds (Yocto Scarthgap blocks them).
[[ "$(id -u)" -eq 0 ]] && fail "Do not run as root. BitBake will refuse."

# ── Source Yocto build environment ────────────────────────────────────────────
section "Sourcing Yocto build environment"
cd "${POKY_DIR}"
set +u
# shellcheck disable=SC1091
source oe-init-build-env "${BUILD_DIR}"
set -u
# We are now in BUILD_DIR.

DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images/myd-yf13x"
START_TIME=$(date +%s)

# ── Step 1: TF-A (first-stage bootloader) ────────────────────────────────────
section "Step 1/7 · TF-A (Trusted Firmware-A BL2)"
log "bitbake virtual/trusted-firmware-a"
bitbake virtual/trusted-firmware-a

# ── Step 2: OP-TEE OS ─────────────────────────────────────────────────────────
section "Step 2/7 · OP-TEE OS (secure world)"
log "bitbake virtual-optee-os"
bitbake virtual-optee-os

# ── Step 3: FIP bundle (TF-A BL31 + OP-TEE + U-Boot) ────────────────────────
section "Step 3/7 · FIP bundle (TF-A BL31 + OP-TEE + U-Boot)"
log "bitbake fip-stm32mp"
bitbake fip-stm32mp

# ── Step 4: Linux kernel ──────────────────────────────────────────────────────
section "Step 4/7 · Linux kernel 6.6"
log "bitbake virtual/kernel"
bitbake virtual/kernel

# ── Step 5: bootfs partition image ───────────────────────────────────────────
section "Step 5/7 · st-image-bootfs (kernel + dtb + extlinux)"
log "bitbake st-image-bootfs"
bitbake st-image-bootfs

# ── Step 6: vendorfs partition image ─────────────────────────────────────────
section "Step 6/7 · st-image-vendorfs (GPU / Wi-Fi / BT firmware)"
log "bitbake st-image-vendorfs"
bitbake st-image-vendorfs

# ── Step 7: userfs partition image ───────────────────────────────────────────
section "Step 7/8 · st-image-userfs (MYIR user-space tools)"
log "bitbake st-image-userfs"
bitbake st-image-userfs

# ── Step 8: full SD card WIC image ─────────────────────────────────────────
section "Step 8/8 · myir-image-sd (full SD card WIC image)"
log "bitbake myir-image-sd"
bitbake myir-image-sd

# ── Build summary ─────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
HOURS=$(( ELAPSED / 3600 ))
MINS=$(( (ELAPSED % 3600) / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║   BUILD COMPLETE                                                 ║${RESET}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
printf  "${BOLD}${GREEN}║${RESET}  Elapsed  : %02dh %02dm %02ds\n" "${HOURS}" "${MINS}" "${SECS}"
echo -e "${BOLD}${GREEN}║${RESET}  Deploy   : ${DEPLOY_DIR}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}${GREEN}║${RESET}  Key artefacts:"
echo -e "${BOLD}${GREEN}║${RESET}    TF-A (BL2):"
ls -1 "${DEPLOY_DIR}/arm-trusted-firmware/"*.stm32 2>/dev/null \
  | sed 's|^|    ║      |' || true
echo -e "${BOLD}${GREEN}║${RESET}    FIP bundle:"
ls -1 "${DEPLOY_DIR}/fip/"*.bin 2>/dev/null \
  | sed 's|^|    ║      |' || true
echo -e "${BOLD}${GREEN}║${RESET}    Partition images:"
ls -1 "${DEPLOY_DIR}/"*.ext4 2>/dev/null \
  | sed 's|^|    ║      |' || true
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}${GREEN}║${RESET}  To write to an SD card under Linux:"
echo -e "${BOLD}${GREEN}║${RESET}    Use STM32CubeProgrammer with the flashlayout .tsv files in:"
echo -e "${BOLD}${GREEN}║${RESET}    ${DEPLOY_DIR}/flashlayout_*/"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
