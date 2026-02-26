#!/usr/bin/env bash
# build-sdcard.sh
#
# Builds the full SD card WIC image for the MYC-YF135 (myd-yf13x).
# Assumes the partition images are already deployed (run build-image.sh first).
#
# Output:
#   build/tmp/deploy/images/myd-yf13x/
#       myir-image-sd-myd-yf13x.rootfs.wic        — write directly with dd
#       myir-image-sd-myd-yf13x.rootfs.wic.gz     — compressed copy
#
# Flash to SD card:
#   zcat myir-image-sd-myd-yf13x.rootfs.wic.gz | sudo dd of=/dev/sdX bs=4M conv=fdatasync status=progress
#   or:
#   sudo dd if=myir-image-sd-myd-yf13x.rootfs.wic of=/dev/sdX bs=4M conv=fdatasync status=progress
# ---------------------------------------------------------------------------
set -euo pipefail

WORKDIR=/workdir
BUILD_DIR="${WORKDIR}/build"
POKY_DIR="${WORKDIR}/poky"
DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images/myd-yf13x"

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'
log()     { echo -e "\n${GREEN}[sdcard]${RESET} ${BOLD}$*${RESET}"; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
            echo -e "${CYAN} $*${RESET}"; \
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
fail()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -d "${POKY_DIR}" ]]  || fail "poky not found at ${POKY_DIR}. Run setup-layers.sh first."
[[ -d "${BUILD_DIR}" ]] || fail "build dir missing. Run setup-layers.sh first."
[[ "$(id -u)" -eq 0 ]]  && fail "Do not run as root."

# Verify that the required partition images are deployed.
BOOTFS="${DEPLOY_DIR}/st-image-bootfs-poky-myd-yf13x.bootfs.ext4"
VENDORFS="${DEPLOY_DIR}/st-image-vendorfs-poky-myd-yf13x.vendorfs.ext4"
USERFS="${DEPLOY_DIR}/st-image-userfs-poky-myd-yf13x.userfs.ext4"
TFA="${DEPLOY_DIR}/arm-trusted-firmware/tf-a-myb-stm32mp135x-512m-optee-sdcard.stm32"
FIP="${DEPLOY_DIR}/fip/fip-myb-stm32mp135x-512m-optee-sdcard.bin"

for f in "${BOOTFS}" "${VENDORFS}" "${USERFS}" "${TFA}" "${FIP}"; do
    [[ -f "${f}" ]] || fail "Required file not found: ${f}\nRun build-image.sh first (steps 1-7)."
done

# ── Source Yocto build environment ────────────────────────────────────────────
section "Sourcing Yocto build environment"
cd "${POKY_DIR}"
set +u
# shellcheck disable=SC1091
source oe-init-build-env "${BUILD_DIR}"
set -u

# ── Build SD card WIC image ───────────────────────────────────────────────────
section "Building myir-image-sd (WIC SD card image)"
log "bitbake myir-image-sd"

START_TIME=$(date +%s)
bitbake myir-image-sd
END_TIME=$(date +%s)

ELAPSED=$(( END_TIME - START_TIME ))
HOURS=$(( ELAPSED / 3600 ))
MINS=$(( (ELAPSED % 3600) / 60 ))
SECS=$(( ELAPSED % 60 ))

# ── Print result ─────────────────────────────────────────────────────────────
WIC=$(ls "${DEPLOY_DIR}"/myir-image-sd-myd-yf13x.rootfs-*.wic 2>/dev/null | tail -1 || true)
[[ -z "${WIC}" ]] && WIC="${DEPLOY_DIR}/myir-image-sd-myd-yf13x.rootfs.wic"

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║   SD CARD IMAGE READY                                            ║${RESET}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
printf  "${BOLD}${GREEN}║${RESET}  Elapsed  : %02dh %02dm %02ds\n" "${HOURS}" "${MINS}" "${SECS}"
echo -e "${BOLD}${GREEN}║${RESET}  Image    : ${WIC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}${GREEN}║${RESET}  Flash:"
echo -e "${BOLD}${GREEN}║${RESET}    sudo dd if=<image>.wic of=/dev/sdX bs=4M conv=fdatasync status=progress"
echo -e "${BOLD}${GREEN}║${RESET}  or (compressed):"
echo -e "${BOLD}${GREEN}║${RESET}    zcat <image>.wic.gz | sudo dd of=/dev/sdX bs=4M conv=fdatasync status=progress"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
