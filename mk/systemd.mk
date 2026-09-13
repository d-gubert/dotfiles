# systemd targets, shared by mk/debian.mk and mk/arch.mk.

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
