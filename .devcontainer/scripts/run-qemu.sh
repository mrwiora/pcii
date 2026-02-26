#!/usr/bin/env bash
# run-qemu.sh
#
# Launches the qemuarm core-image-minimal image built by build-qemu.sh.
# Uses "nographic" mode so it works in headless/container environments.
#
# Login: root (no password)
# Exit QEMU: Ctrl-A x
# ---------------------------------------------------------------------------
set -euo pipefail

WORKDIR=/workdir
BUILD_DIR="${WORKDIR}/build-qemu"
POKY_DIR="${WORKDIR}/poky"

DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images/qemuarm"

RED='\033[0;31m'; GREEN='\033[0;32m'; BOLD='\033[1m'; RESET='\033[0m'
fail() { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

[[ -d "${POKY_DIR}" ]]                          || fail "poky not found at ${POKY_DIR}. Run setup-layers.sh first."
[[ -d "${DEPLOY_DIR}" ]]                        || fail "QEMU deploy dir missing. Run build-qemu.sh first."

echo -e "${BOLD}${GREEN}Starting qemuarm …${RESET}"
echo -e "  Login : root (no password)"
echo -e "  Exit  : Ctrl-A x"
echo ""

QEMUBOOT_CONF="${DEPLOY_DIR}/core-image-minimal-qemuarm.rootfs.qemuboot.conf"
[[ -f "${QEMUBOOT_CONF}" ]] || fail "qemuboot.conf not found: ${QEMUBOOT_CONF}"

cd "${POKY_DIR}"
set +u
# shellcheck disable=SC1091
source oe-init-build-env "${BUILD_DIR}" > /dev/null
set -u

# Pass the absolute qemuboot.conf path so runqemu doesn't need to invoke bitbake.
# Use "slirp" (user-mode networking) — Docker containers lack /dev/net/tun.
cd "${DEPLOY_DIR}"
runqemu "${QEMUBOOT_CONF}" nographic slirp
