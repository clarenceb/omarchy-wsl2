# omarchy-wsl2 - build Omarchy as an installable WSL2 distribution.
#
#   make            show this help
#   make all        fetch -> seed -> build -> export
#   make install    install the built .wsl on Windows
#
# Run every target from inside an existing WSL2 distro (Ubuntu is fine).

SHELL := /bin/bash
.DEFAULT_GOAL := help
.ONESHELL:

# ----------------------------------------------------------------- config ---
# WSL exports a NAME environment variable (the Windows hostname), which would
# otherwise win over `?=`. Ignore it unless NAME was given on the command line.
ifeq ($(origin NAME), environment)
  NAME := omarchy
endif

NAME          ?= omarchy
DISTRO        ?= $(NAME)
BUILD_DISTRO  ?= $(NAME)-build
PROFILE       ?= desktop
ARCH          ?= $(shell uname -m)
OMARCHY_REF   ?= master
OMARCHY_REPO  ?= basecamp/omarchy
OMARCHY_THEME ?= Tokyo Night
OMARCHY_LAYOUT ?= tiling
OMARCHY_USER  ?= omarchy
# 1001 avoids colliding with the near-universal uid 1000 of other WSL distros.
OMARCHY_UID   ?= 1001

# Large artefacts live on the Windows drive: wsl.exe needs Windows paths for
# --import/--export, and NTFS avoids a 9p round-trip for multi-GB files.
WIN_ROOT      ?= /mnt/c/wsl/omarchy-wsl2
CACHE_DIR     ?= $(WIN_ROOT)/cache
# Per-distro subdirectory: two builds under different NAMEs must not share a
# directory, or wsl --import fails with ERROR_FILE_EXISTS.
BUILD_DIR     ?= $(WIN_ROOT)/build/$(BUILD_DISTRO)
DIST_DIR      ?= $(WIN_ROOT)/dist
OUT_NAME      ?= $(NAME)-$(PROFILE)-$(ARCH)

export ARCH OMARCHY_REF OMARCHY_REPO OMARCHY_THEME OMARCHY_LAYOUT OMARCHY_USER OMARCHY_UID

S := ./scripts

# ---------------------------------------------------------------- wizard ----
.PHONY: wizard
wizard:
	@./omarchy-wsl2

# ------------------------------------------------------------------ help ----
.PHONY: help
help:
	@printf '\n\033[1;36momarchy-wsl2\033[0m - Omarchy as a WSL2 distribution\n\n'
	@printf '  \033[1;35mNew here?\033[0m Run \033[36m./omarchy-wsl2\033[0m for the guided wizard.\n\n'
	@printf '\033[1mBuild pipeline\033[0m\n'
	@printf '  %-16s %s\n' \
	  'make check'    'verify WSL version, architecture and host tooling' \
	  'make logo'     'render assets/*.png and the Windows .ico' \
	  'make fetch'    'download the Arch base rootfs into $(CACHE_DIR)' \
	  'make seed'     'import the base rootfs as the throwaway build distro' \
	  'make build'    'provision Omarchy inside the build distro' \
	  'make export'   'produce $(DIST_DIR)/$(OUT_NAME).wsl' \
	  'make all'      'fetch + seed + build + export'
	@printf '\n\033[1mUse it\033[0m\n'
	@printf '  %-16s %s\n' \
	  'make install'  'wsl --install --from-file the built image' \
	  'make run'      'open a shell in the installed distro' \
	  'make doctor'   'run omarchy-wsl-doctor in the installed distro' \
	  'make uninstall' 'unregister the installed distro'
	@printf '\n\033[1mHousekeeping\033[0m\n'
	@printf '  %-16s %s\n' \
	  'make shell'    'root shell inside the build distro (debugging)' \
	  'make clean'    'remove the build distro and build dir' \
	  'make distclean' 'also remove the download cache and dist output' \
	  'make lint'     'shellcheck all scripts'
	@printf '\n\033[1mVariables\033[0m\n'
	@printf '  %-16s %s\n' \
	  'PROFILE'       'headless | apps | desktop   (current: $(PROFILE))' \
	  'ARCH'          'x86_64 | aarch64            (current: $(ARCH))' \
	  'OMARCHY_REF'   'Omarchy git ref             (current: $(OMARCHY_REF))' \
	  'OMARCHY_THEME' 'initial theme               (current: $(OMARCHY_THEME))' \
	  'OMARCHY_LAYOUT' 'tiling or floating         (current: $(OMARCHY_LAYOUT))' \
	  'NAME'          'installed distro name       (current: $(NAME))' \
	  'WIN_ROOT'      'artefact root               (current: $(WIN_ROOT))'
	@printf '\n  e.g. \033[36mmake all PROFILE=headless\033[0m\n\n'

# ----------------------------------------------------------------- checks ---
.PHONY: check
check:
	@source $(S)/lib.sh
	require_wsl_host
	check_wsl_version
	step "Target architecture: $$(target_arch)"
	step "Profile: $(PROFILE)"
	if [[ "$(ARCH)" == "aarch64" ]]; then
	  warn "aarch64: Omarchy's pacman repo is x86_64-only - see docs/08-arm64.md"
	fi
	for t in curl tar gzip python3; do
	  command -v $$t >/dev/null || die "missing required tool: $$t"
	done
	step "Host tooling OK"
	log "Ready to build"

# ------------------------------------------------------------------ logo ----
.PHONY: logo
logo:
	@python3 $(S)/make-logo.py
	@python3 $(S)/make-wallpaper.py

assets/omarchy-wsl2.ico: assets/logo.svg
	@python3 $(S)/make-logo.py

# ------------------------------------------------------------- pipeline -----
.PHONY: fetch
fetch:
	@mkdir -p $(CACHE_DIR)
	@$(S)/fetch-rootfs.sh $(CACHE_DIR)

.PHONY: seed
seed:
	@$(S)/seed.sh $(CACHE_DIR) $(BUILD_DIR) $(BUILD_DISTRO)

.PHONY: build
build: assets/omarchy-wsl2.ico
	@$(S)/provision.sh $(BUILD_DISTRO) $(PROFILE)

.PHONY: export
export:
	@mkdir -p $(DIST_DIR)
	@$(S)/export.sh $(BUILD_DISTRO) $(DIST_DIR) $(OUT_NAME)

.PHONY: all
all: check logo fetch seed build export

# --------------------------------------------------------------- install ----
.PHONY: install
install:
	@source $(S)/lib.sh
	IMG="$(DIST_DIR)/$(OUT_NAME).wsl"
	[[ -s "$$IMG" ]] || die "Not built yet: $$IMG  (run: make all)"
	unregister_distro "$(DISTRO)"
	log "Installing '$(DISTRO)' from $$IMG"
	wsl.exe --install --from-file "$$(winpath "$$IMG")" --name "$(DISTRO)" \
	  || die "wsl --install failed"
	log "Installed. Start it with: wsl -d $(DISTRO)"

.PHONY: run
run:
	@wsl.exe -d $(DISTRO)

.PHONY: doctor
doctor:
	@wsl.exe -d $(DISTRO) -- omarchy-wsl-doctor

.PHONY: uninstall
uninstall:
	@source $(S)/lib.sh
	unregister_distro "$(DISTRO)"
	log "Unregistered '$(DISTRO)'"

# ----------------------------------------------------------- housekeeping ---
.PHONY: shell
shell:
	@wsl.exe -d $(BUILD_DISTRO) -u root

.PHONY: clean
clean:
	@source $(S)/lib.sh
	unregister_distro "$(BUILD_DISTRO)"
	rm -rf $(BUILD_DIR)
	log "Removed the build distro and $(BUILD_DIR)"

.PHONY: distclean
distclean: clean
	@rm -rf $(CACHE_DIR) $(DIST_DIR) assets/*.png assets/*.ico
	@echo "Removed cache, dist and generated artwork"

.PHONY: lint
lint:
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	@# Only shell scripts: omarchy-wsl-wt and make-logo.py are Python.
	@shellcheck -S warning -e SC1091,SC2317,SC1090 \
	  $(S)/*.sh $(S)/provision/*.sh wsl/oobe.sh ./omarchy-wsl2 \
	  overlay/usr/local/bin/omarchy-wsl-app \
	  overlay/usr/local/bin/omarchy-wsl-desktop \
	  overlay/usr/local/bin/omarchy-wsl-devtools \
	  overlay/usr/local/bin/omarchy-wsl-doctor \
	  overlay/usr/local/bin/omarchy-wsl-env \
	  overlay/usr/local/bin/omarchy-wsl-help \
	  overlay/opt/omarchy-learn/bin/omarchy-learn \
	  && echo "shellcheck clean"
	@python3 -m py_compile $(S)/make-logo.py overlay/usr/local/bin/omarchy-wsl-wt \
	  && echo "python syntax clean"
	@rm -rf $(S)/__pycache__ overlay/usr/local/bin/__pycache__ 2>/dev/null || true
