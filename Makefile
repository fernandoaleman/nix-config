.DEFAULT_GOAL := help

# ── Contributor setup ──────────────────────────────────
# Tooling for *editing* this repo, not for bringing a machine up. Git hooks do
# not travel with a clone, so this runs once per clone, and it must work before
# Nix is installed — hence Make, and hence nothing here may depend on Nix.
#
# PREK_NO_MODIFY_PATH=1 stops the installer writing to five shell rc files
# (~/.profile, ~/.bashrc, ~/.bash_profile, ~/.zshrc, fish conf.d). The
# installer has a guard meant to skip that when its install directory is
# already on PATH, but the guard string-matches PATH against
# $XDG_DATA_HOME/../bin — literally ".local/share/../bin" — while Omarchy's
# env-bootstrap appends the normalised ".local/bin". Same directory, different
# spelling, guard misses. ~/.local/bin is already on PATH on both targets, so
# suppressing the rc edits loses nothing. See plans/bootstrap.md.
.PHONY: setup
setup: ## Install prek and activate git hooks
	@command -v prek >/dev/null 2>&1 || { \
		echo "Installing prek..."; \
		if command -v brew >/dev/null 2>&1; then \
			brew install prek; \
		else \
			curl --proto '=https' --tlsv1.2 -LsSf https://github.com/j178/prek/releases/latest/download/prek-installer.sh | PREK_NO_MODIFY_PATH=1 sh; \
		fi; \
	}
	prek install
	prek install --hook-type commit-msg
	@echo "Done. Hooks are active."

.PHONY: ssh
ssh: ## Switch the origin remote from HTTPS to SSH
	@url=$$(git remote get-url origin); \
	case "$$url" in \
		https://github.com/*) \
			new="git@github.com:$${url#https://github.com/}"; \
			git remote set-url origin "$$new"; \
			echo "origin -> $$new" ;; \
		git@github.com:*) \
			echo "origin already SSH: $$url" ;; \
		*) \
			echo "unrecognised origin: $$url" >&2; exit 1 ;; \
	esac

# ── Lint ───────────────────────────────────────────────
.PHONY: lint
lint: ## Run all pre-commit hooks on every file
	prek run --all-files

.PHONY: lint-fix
lint-fix: ## Run fixable hooks (trailing-whitespace, end-of-file-fixer)
	prek run trailing-whitespace end-of-file-fixer --all-files

# ── Machine bootstrap ──────────────────────────────────
# Bringing up a *fresh Omarchy install* — a different job from `make setup`,
# which only arms git hooks for someone editing this repo. Added once the flake
# exists; the full sequence and its rationale live in plans/bootstrap.md.
#
#   bootstrap      nix-subvolume -> nix-install -> make switch
#   nix-subvolume  create @nix + fstab entry + updatedb PRUNEPATHS
#   nix-install    NixOS/nix-installer (the Foundation fork, upstream Nix):
#                  curl -sSfL https://artifacts.nixos.org/nix-installer \
#                    | sh -s -- install --enable-flakes --no-confirm
#
# `nix-subvolume` is the one step that cannot be undone cheaply and cannot be
# deferred: /nix has to be a separate Btrfs subvolume BEFORE Nix is installed,
# or the store lands on @ and every Snapper rollback reverts it. It needs root,
# so it is the one place the bootstrap asks for sudo.

# ── Nix ────────────────────────────────────────────────
# Replaces the chezmoi diff/apply/verify targets from the previous repo.
#
# The configuration is named "<user>@<host>", the form home-manager's own CLI
# looks for when given a bare `--flake .`. It is passed explicitly all the same,
# so a switch never depends on what the machine currently calls itself -- this
# box still answers to Omarchy's default hostname, `omarchy`.
HM ?= faleman@beelink

.PHONY: switch
switch: ## Build and activate the configuration
	home-manager switch --flake .#$(HM)

.PHONY: build
build: ## Build without activating; leaves ./result to inspect
	nix build '.#homeConfigurations."$(HM)".activationPackage'

.PHONY: check
check: ## Evaluate the flake without building
	nix flake check

.PHONY: update
update: ## Update all flake inputs and rewrite flake.lock
	nix flake update

.PHONY: generations
generations: ## List home-manager generations, newest last
	home-manager generations

.PHONY: rollback
rollback: ## Activate the previous generation
	home-manager rollback

# ── Help ───────────────────────────────────────────────
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
