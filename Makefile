# Makefile — PCII Yocto build helpers
#
# All targets that run inside the devcontainer are prefixed with
# `devcontainer exec --workspace-folder .`.
# The container must already be running (`make up` or `devcontainer up`).
#
# Typical first-time workflow:
#   make build         # alias: build STM32MP + QEMU images
#
# Individual targets:
#   make up            # start devcontainer (also runs setup-layers.sh)
#   make build-stm32   # build full STM32MP135 image set
#   make build-qemu    # build qemuarm core-image-minimal
#   make run-qemu      # launch QEMU in the terminal (Ctrl-A x to exit)
#   make shell         # open a bash shell in the container
# ---------------------------------------------------------------------------

WORKSPACE_FOLDER := .
DC_EXEC          := devcontainer exec --workspace-folder $(WORKSPACE_FOLDER) bash

SCRIPTS := /workdir/.devcontainer/scripts

.PHONY: all build up setup build-stm32 build-sdcard build-qemu run-qemu shell

# Default: build everything
all: build

# Build both target images (requires container already up)
build: build-stm32 build-qemu

# ── Container lifecycle ───────────────────────────────────────────────────────

## Start the devcontainer (setup-layers.sh runs as postCreateCommand)
up:
	devcontainer up --workspace-folder $(WORKSPACE_FOLDER)

## Re-run setup-layers.sh inside an already-running container
setup:
	$(DC_EXEC) $(SCRIPTS)/setup-layers.sh

## Open an interactive shell in the container
shell:
	devcontainer exec --workspace-folder $(WORKSPACE_FOLDER) bash

# ── Build targets ─────────────────────────────────────────────────────────────

## Full STM32MP135 image set (TF-A → OP-TEE → FIP → kernel → bootfs/vendorfs/userfs)
build-stm32:
	$(DC_EXEC) $(SCRIPTS)/build-image.sh

## SD card WIC image only (requires build-stm32 to have run first)
build-sdcard:
	$(DC_EXEC) $(SCRIPTS)/build-sdcard.sh

## qemuarm core-image-minimal — bootable in QEMU without real hardware
build-qemu:
	$(DC_EXEC) $(SCRIPTS)/build-qemu.sh

# ── Run QEMU ─────────────────────────────────────────────────────────────────

## Launch the qemuarm image (nographic; login: root / no password; Ctrl-A x to quit)
run-qemu:
	$(DC_EXEC) $(SCRIPTS)/run-qemu.sh

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  PCII Yocto build targets"
	@echo ""
	@echo "  make up            Start devcontainer + run setup-layers.sh"
	@echo "  make setup         Re-run setup-layers.sh (re-init build dirs)"
	@echo "  make build         Build both STM32MP and QEMU images"
	@echo "  make build-stm32   Build full STM32MP135 image set (steps 1-8)"
	@echo "  make build-sdcard  Build SD card WIC only (requires build-stm32 first)"
	@echo "  make build-qemu    Build qemuarm core-image-minimal"
	@echo "  make run-qemu      Launch QEMU (nographic, Ctrl-A x to exit)"
	@echo "  make shell         Open shell in the running container"
	@echo ""
	@echo "  Output (STM32MP):"
	@echo "    build/tmp/deploy/images/myd-yf13x/"
	@echo "    SD card: myir-image-sd-poky-myd-yf13x.wic (.wic.gz)"
	@echo ""
	@echo "  Output (QEMU):"
	@echo "    build-qemu/tmp/deploy/images/qemuarm/"
	@echo ""
