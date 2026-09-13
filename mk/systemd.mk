# systemd and udev targets, shared by mk/debian.mk and mk/arch.mk.

# logind — make the laptop do nothing when the lid closes on AC power
#          (battery still suspends). Lives under system/ mirroring /.
.PHONY: logind-config
logind-config:
	@if sudo cmp -s system/etc/systemd/logind.conf.d/lid.conf /etc/systemd/logind.conf.d/lid.conf 2>/dev/null; then \
		echo "[logind] already configured"; \
	else \
		echo "[logind] installing lid drop-in to /etc..."; \
		sudo install -D -m 0644 system/etc/systemd/logind.conf.d/lid.conf /etc/systemd/logind.conf.d/lid.conf; \
		sudo systemctl kill -s HUP systemd-logind; \
	fi

# uinput — kanata reads the keyboard through /dev/input and writes the remapped
#          keys back through /dev/uinput. The kernel owns both as root, so
#          kanata fails with "Permission denied (os error 13)" until the user
#          is in the input and uinput groups and a udev rule opens the node to
#          that group. See https://github.com/jtroo/kanata/blob/main/docs/setup-linux.md
#
#          Two traps. First, systemd-tmpfiles creates a root-only placeholder
#          /dev/uinput at boot, so the node exists before the module loads.
#          Test lsmod, not the node. Second, `id -nG $USER` reads the group
#          database, not the session. Test `id -nG` alone for the live session.
.PHONY: uinput-config
uinput-config:
	@if getent group uinput >/dev/null 2>&1; then echo "[uinput] group already exists"; else \
		echo "[uinput] creating the uinput system group..."; \
		sudo groupadd --system uinput; \
	fi
	@for g in input uinput; do \
		if id -nG "$$USER" | grep -qw "$$g"; then echo "[uinput] already in the $$g group"; else \
			echo "[uinput] adding $$USER to the $$g group..."; \
			sudo usermod -aG "$$g" $$USER; \
		fi; \
	done
	@if sudo cmp -s system/etc/udev/rules.d/99-uinput.rules /etc/udev/rules.d/99-uinput.rules 2>/dev/null; then \
		echo "[uinput] udev rule already installed"; \
	else \
		echo "[uinput] installing the udev rule to /etc..."; \
		sudo install -D -m 0644 system/etc/udev/rules.d/99-uinput.rules /etc/udev/rules.d/99-uinput.rules; \
		sudo udevadm control --reload-rules; \
	fi
	@if sudo cmp -s system/etc/modules-load.d/uinput.conf /etc/modules-load.d/uinput.conf 2>/dev/null; then \
		echo "[uinput] boot-time module load already configured"; \
	else \
		echo "[uinput] installing the module drop-in to /etc..."; \
		sudo install -D -m 0644 system/etc/modules-load.d/uinput.conf /etc/modules-load.d/uinput.conf; \
	fi
	@if lsmod | grep -q "^uinput "; then echo "[uinput] module already loaded"; else \
		echo "[uinput] loading the uinput module..."; \
		sudo modprobe uinput; \
	fi
	@if [ "$$(stat -c '%G %a' /dev/uinput)" = "uinput 660" ]; then \
		echo "[uinput] /dev/uinput belongs to the uinput group"; \
	else \
		echo "[uinput] applying the udev rule to /dev/uinput..."; \
		sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput; \
		sudo udevadm settle; \
		stat -c '[uinput] /dev/uinput is now %U:%G %a' /dev/uinput; \
	fi
	@if id -nG | grep -qw uinput && id -nG | grep -qw input; then \
		echo "[uinput] this session has the input and uinput groups"; \
	else \
		echo "[uinput] NOTE: this session has no input or uinput group."; \
		echo "[uinput] NOTE: log out and back in, then start kanata again."; \
	fi
