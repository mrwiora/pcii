#!/usr/bin/env bash
# setup-layers.sh
#
# Called once by devcontainer postCreateCommand.
# Clones the required Yocto base layers (poky, meta-openembedded),
# initialises the build directory, adds all layers to bblayers.conf,
# and writes a sane local.conf for the myd-yf13x (MYC-YF135) machine.
#
# Safe to re-run; already-present repos and conf entries are skipped.
# ---------------------------------------------------------------------------
set -euo pipefail

WORKDIR=/workdir
BUILD_DIR="${WORKDIR}/build"
POKY_DIR="${WORKDIR}/poky"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
log()  { echo -e "${GREEN}[setup]${RESET} $*"; }
warn() { echo -e "${YELLOW}[warn ]${RESET} $*"; }

# ── Fix volume permissions (Docker volumes are root-owned on first creation) ──
sudo chown -R "$(id -u):$(id -g)" \
    "${WORKDIR}/yocto-downloads" \
    "${WORKDIR}/yocto-sstate-cache" 2>/dev/null || true

# ── Helper: shallow-clone a layer if not already present ─────────────────────
clone_layer() {
    local name="$1" url="$2" branch="$3"
    local dest="${WORKDIR}/${name}"
    if [[ -d "${dest}/.git" ]]; then
        log "${name} already present - skipping clone"
    else
        log "Cloning ${name} @ ${branch} ..."
        git clone --depth=1 --single-branch -b "${branch}" \
            "${url}" "${dest}"
        log "${name} cloned successfully"
    fi
}

# ── 1. Fetch Yocto base layers ────────────────────────────────────────────────
log "=== Step 1/4: Fetching base Yocto layers (Scarthgap 5.0 LTS) ==="

clone_layer "poky" \
    "https://git.yoctoproject.org/poky" \
    "scarthgap"

clone_layer "meta-openembedded" \
    "https://github.com/openembedded/meta-openembedded.git" \
    "scarthgap"

# ── 2. Initialise the Yocto build environment ─────────────────────────────────
log "=== Step 2/4: Initialising build environment in ${BUILD_DIR} ==="

# oe-init-build-env must be *sourced*; it also changes CWD to BUILD_DIR.
# Temporarily disable "unbound variable" (-u) because oe-init-build-env
# references several vars that may not yet be set (BBSERVER, BBPATH, etc.).
cd "${POKY_DIR}"
set +u
# shellcheck disable=SC1091
source oe-init-build-env "${BUILD_DIR}"
set -u
# After sourcing we are now in BUILD_DIR.

# ── 3. Add extra layers (idempotent via bitbake-layers) ───────────────────────
log "=== Step 3/4: Registering Yocto layers ==="

add_if_missing() {
    local path="$1"
    local name; name="$(basename "${path}")"
    if bitbake-layers show-layers 2>/dev/null | awk '{print $1}' | grep -qx "${name}"; then
        log "  already registered: ${name}"
    else
        log "  adding layer: ${name}"
        bitbake-layers add-layer "${path}"
    fi
}

add_if_missing "${WORKDIR}/meta-openembedded/meta-oe"
add_if_missing "${WORKDIR}/meta-openembedded/meta-python"
add_if_missing "${WORKDIR}/meta-myir-stm32mp"

# ── 4. Write local.conf ───────────────────────────────────────────────────────
log "=== Step 4/4: Writing build/conf/local.conf ==="

LOCAL_CONF="${BUILD_DIR}/conf/local.conf"
NCPUS="$(nproc)"

# Helper: remove any existing assignment for KEY then append clean.
conf_set() {
    local key="$1" val="$2"
    sed -i "/^${key}[[:space:]]*[?:+!]*=/d" "${LOCAL_CONF}" 2>/dev/null || true
    echo "${key} = \"${val}\"" >> "${LOCAL_CONF}"
}

# ── Target machine & distro ──────────────────────────────────────────────────
conf_set MACHINE              "myd-yf13x"
conf_set DISTRO               "poky"
conf_set CONF_VERSION         "2"

# ── Accept ST/MYIR EULA ───────────────────────────────────────────────────────
conf_set "ACCEPT_EULA_myd-yf13x"  "1"

# ── Parallelism ───────────────────────────────────────────────────────────────
conf_set BB_NUMBER_THREADS    "${NCPUS}"
conf_set PARALLEL_MAKE        "-j${NCPUS}"

# ── Persistent artefact caches (Docker volumes) ───────────────────────────────
conf_set DL_DIR               "/workdir/yocto-downloads"
conf_set SSTATE_DIR           "/workdir/yocto-sstate-cache"

# ── Fix: STM32MP machine includes reference IMAGE_BASENAME in STM32MP_ROOTFS_IMAGE
# ── which is only set inside image recipes.  Providing a static default here   ──
# ── prevents "AttributeError: NoneType has no attribute replace" at parse time. ──
conf_set STM32MP_ROOTFS_IMAGE "core-image-minimal"

# ── Fix: linux-examples-stm32mp1-userfs scripts need /bin/sh but st-image-userfs
# ── has no shell installed.  Mark it as a bad recommendation so DNF skips it. ──
echo 'BAD_RECOMMENDATIONS:append = " linux-examples-stm32mp1-userfs"' >> "${LOCAL_CONF}"
echo ""
echo -e "${BOLD}${GREEN}=====================================================================${RESET}"
echo -e "${BOLD}${GREEN}  Yocto Scarthgap build environment ready for myd-yf13x${RESET}"
echo -e "${BOLD}${GREEN}=====================================================================${RESET}"
echo -e "  Build dir : ${BUILD_DIR}"
echo -e "  Downloads : /workdir/yocto-downloads  (Docker volume)"
echo -e "  sstate    : /workdir/yocto-sstate-cache  (Docker volume)"
echo -e "  CPUs      : ${NCPUS}"
echo ""
echo -e "  To build the full image set:"
echo -e "    bash /workdir/.devcontainer/scripts/build-image.sh"
echo ""
echo -e "  To build manually:"
echo -e "    cd /workdir/poky"
echo -e "    source oe-init-build-env /workdir/build"
echo -e "    bitbake st-image-bootfs"
echo -e "${BOLD}${GREEN}=====================================================================${RESET}"
