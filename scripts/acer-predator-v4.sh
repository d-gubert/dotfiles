#!/usr/bin/env bash
# Enable Acer Predator Sense v4 features in the mainline acer-wmi driver.
#
# The in-tree acer-wmi module gates all PredatorSense-v4 features (the
# performance/"turbo" platform profiles and the fan RPM sensors) behind the
# module parameter `predator_v4`, which defaults to N. On PredatorSense-v4
# laptops (e.g. Predator PH315-54) this means /sys/class/platform-profile/ is
# empty and there are no fan controls until the parameter is turned on.
#
# The parameter is read-only at runtime, so it can only be set when the module
# loads. This script reloads acer-wmi with predator_v4=1 and, with --persist,
# drops a modprobe.d snippet so it survives reboots.
#
# Usage:
#   scripts/acer-predator-v4.sh            # enable now (reload module)
#   scripts/acer-predator-v4.sh --persist  # enable now + persist across reboots
#   scripts/acer-predator-v4.sh --status   # just report current state
#   scripts/acer-predator-v4.sh --toggle   # flip balanced <-> performance (max fans)
#   scripts/acer-predator-v4.sh --set X    # set a specific profile
#
# The physical Turbo button on the PH315-54 is handled entirely in the EC and
# emits no input/ACPI event, so it cannot be hooked from Linux. Bind --toggle
# to a keyboard shortcut instead; it needs no root when power-profiles-daemon
# is running (see ../scripts/archive/acer-predator-v4-troubleshooting.md).
set -euo pipefail

MODULE="acer_wmi"
PARAM_FILE="/sys/module/${MODULE}/parameters/predator_v4"
MODPROBE_CONF="/etc/modprobe.d/acer-wmi.conf"

msg()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

param_value() {
	# Prints Y / N, or "unloaded" if the module isn't loaded.
	[[ -r "$PARAM_FILE" ]] && cat "$PARAM_FILE" || echo "unloaded"
}

report_state() {
	msg "Model:       $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
	msg "predator_v4: $(param_value)"
	if compgen -G '/sys/class/platform-profile/*/' > /dev/null; then
		for p in /sys/class/platform-profile/*/; do
			msg "Profiles:    $(cat "$p"name): $(cat "$p"choices)"
		done
	else
		msg "Profiles:    (none registered)"
	fi
	local fans
	fans=$(find /sys/devices/platform/acer-wmi -iname '*fan*_input' 2>/dev/null | wc -l)
	msg "Fan sensors: ${fans}"
}

# --- profile switching -------------------------------------------------------
# power-profiles-daemon (PPD), when running, owns the platform profile: writing
# sysfs directly fights it and can be reverted underneath us. Prefer its D-Bus
# interface, which also means no root is needed (important for a keybind).
# PPD exposes only performance/balanced/power-saver; raw sysfs has all five.

ppd_running() { systemctl is-active --quiet power-profiles-daemon 2>/dev/null; }

get_profile() {
	if ppd_running && command -v powerprofilesctl >/dev/null; then
		powerprofilesctl get 2>/dev/null
	else
		cat /sys/class/platform-profile/*/profile 2>/dev/null | head -1
	fi
}

set_profile() {
	local want="$1"
	if ppd_running && command -v powerprofilesctl >/dev/null; then
		# Map the acer-wmi profile names onto PPD's smaller set.
		case "$want" in
			performance|balanced-performance) want=performance ;;
			balanced)                         want=balanced ;;
			quiet|low-power|power-saver)      want=power-saver ;;
		esac
		powerprofilesctl set "$want" || die "powerprofilesctl could not set '$want'"
	else
		local f
		f=$(echo /sys/class/platform-profile/*/profile)
		[[ -e "$f" ]] || die "no platform profile found (is predator_v4 enabled?)"
		# Direct sysfs write needs root.
		if [[ "$EUID" -ne 0 ]]; then
			echo "$want" | sudo tee "$f" >/dev/null
		else
			echo "$want" > "$f"
		fi
	fi
	msg "profile -> $(get_profile)"
}

PERSIST=0
STATUS_ONLY=0
ACTION=""
SET_TO=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--persist) PERSIST=1 ;;
		--status)  STATUS_ONLY=1 ;;
		--toggle)  ACTION=toggle ;;
		--set)     ACTION=set; SET_TO="${2:-}"; [[ -n "$SET_TO" ]] || die "--set needs a profile name"; shift ;;
		-h|--help)
			# Print the leading comment block (everything up to the first blank/non-# line).
			sed -n '2,/^[^#]/p' "$0" | sed '/^[^#]/d; s/^# \{0,1\}//'
			exit 0 ;;
		*) die "unknown argument: $1 (try --help)" ;;
	esac
	shift
done

# Handle profile actions before the sudo re-exec below — via PPD these need no
# root, and prompting for a password would defeat the point of a keybind.
case "$ACTION" in
	toggle)
		cur=$(get_profile)
		if [[ "$cur" == "performance" ]]; then set_profile balanced; else set_profile performance; fi
		exit 0 ;;
	set)
		set_profile "$SET_TO"
		exit 0 ;;
esac

# Sanity check: is this even an Acer machine with the driver available?
vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
[[ "$vendor" == *Acer* ]] || warn "system vendor is '${vendor:-unknown}', not Acer — continuing anyway"
modinfo "$MODULE" >/dev/null 2>&1 || die "$MODULE module not found on this system"
modinfo "$MODULE" 2>/dev/null | grep -q 'parm:.*predator_v4' \
	|| die "$MODULE on this kernel has no predator_v4 parameter (kernel too old?)"

if [[ "$STATUS_ONLY" == 1 ]]; then
	report_state
	exit 0
fi

# Re-exec under sudo if we're not root (modprobe + writing /etc need privileges).
if [[ "$EUID" -ne 0 ]]; then
	msg "Re-running with sudo…"
	exec sudo "$0" "$@"
fi

current=$(param_value)
if [[ "$current" == "Y" ]]; then
	msg "predator_v4 already enabled — no reload needed."
else
	msg "predator_v4 is '${current}' — reloading ${MODULE} with predator_v4=1…"
	modprobe -r "$MODULE"
	modprobe "$MODULE" predator_v4=1
	[[ "$(param_value)" == "Y" ]] || die "reload did not enable predator_v4"
	msg "Reloaded."
fi

if [[ "$PERSIST" == 1 ]]; then
	if [[ -f "$MODPROBE_CONF" ]] && grep -q 'predator_v4=1' "$MODPROBE_CONF"; then
		msg "Persistence already configured in $MODPROBE_CONF"
	else
		echo 'options acer_wmi predator_v4=1' > "$MODPROBE_CONF"
		msg "Wrote $MODPROBE_CONF"
		update-initramfs -u >/dev/null 2>&1 || warn "update-initramfs failed or not present"
		msg "Persistence configured (applies on next boot)."
	fi
fi

echo
report_state
echo
msg "Turn fans to max/turbo:  echo performance | sudo tee /sys/class/platform-profile/*/profile"
msg "Back to normal:          echo balanced    | sudo tee /sys/class/platform-profile/*/profile"
