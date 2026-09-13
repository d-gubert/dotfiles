# Vendor `curl | sh` installers. mk/darwin.mk and mk/debian.mk include this
# file. Arch gets the same tools from a package, so mk/arch.mk does not.
#
# These guards are real. A vendor script is not idempotent, so re-running it
# reinstalls the tool. That is the opposite of a package manager, which is why
# the package targets carry no guard.

# volta manages the node toolchain on these two families.
EXTRA_DEVELOPMENT := install-volta

.PHONY: install-docker
install-docker: install-curl
	@if command -v docker >/dev/null 2>&1; then echo "[docker] already installed"; else \
		echo "[docker] installing via official script (docker-ce)..."; \
		curl -fsSL https://get.docker.com | sudo sh; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] NOTE: log out and back in for group membership to take effect"; \
	fi

.PHONY: install-brave-browser
install-brave-browser: install-curl
	@if command -v brave-browser >/dev/null 2>&1; then echo "[brave-browser] already installed"; else \
		echo "[brave-browser] installing via official script..."; \
		curl -fsS https://dl.brave.com/install.sh | sh; \
	fi

.PHONY: install-volta
install-volta: install-curl
	@if command -v volta >/dev/null 2>&1; then echo "[volta] already installed"; else \
		echo "[volta] installing via official script..."; \
		curl -fsSL https://get.volta.sh | bash; \
	fi

.PHONY: install-node
install-node: install-volta
	@if command -v node >/dev/null 2>&1; then echo "[node] already installed"; else \
		echo "[node] installing with volta..."; \
		volta install node; \
	fi

.PHONY: install-dvm
install-dvm: install-curl
	@if command -v dvm >/dev/null 2>&1; then echo "[dvm] already installed"; else \
		echo "[dvm] installing via official script..."; \
		curl -fsSL https://dvm.deno.dev | sh; \
	fi
