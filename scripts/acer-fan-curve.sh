#!/usr/bin/env bash
# Temperature-driven power-profile switching for Acer Predator laptops.
#
# The PH315-54 exposes no writable fan/PWM control on Linux (mainline acer-wmi
# gives read-only RPM + temp sensors only), so true fan curves aren't possible
# without an out-of-tree module. What *does* work is the platform profile:
# `performance` drives both fans to max. This polls the temperature sensors and
# switches profiles at thresholds — a coarse fan curve built on what works.
#
# Switching goes through power-profiles-daemon when it's running, because PPD
# owns the platform profile and would otherwise revert direct sysfs writes.
#
# Manual overrides are respected: if the profile changes to something this
# daemon didn't set, it backs off until temps cross a threshold again.
#
# Usage:
#   scripts/acer-fan-curve.sh                 # run in foreground (Ctrl-C to stop)
#   scripts/acer-fan-curve.sh --dry-run       # log decisions, change nothing
#   scripts/acer-fan-curve.sh --once          # evaluate once and exit
#   scripts/acer-fan-curve.sh --install       # install+enable the systemd unit
#   scripts/acer-fan-curve.sh --uninstall     # remove the systemd unit
#
# Tunables (env vars, or override in the systemd unit):
#   FAN_HOT=70     degC at/above which we go to performance
#   FAN_COOL=65    degC at/below which we drop back to balanced
#   FAN_INTERVAL=5 seconds between polls
set -euo pipefail

HOT="${FAN_HOT:-70}"
COOL="${FAN_COOL:-65}"
INTERVAL="${FAN_INTERVAL:-5}"

HOT_PROFILE="performance"
COOL_PROFILE="balanced"

UNIT_PATH="/etc/systemd/system/acer-fan-curve.service"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

DRY_RUN=0
ONCE=0

msg()  { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

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
	if [[ "$DRY_RUN" == 1 ]]; then
		msg "[dry-run] would set profile -> $want"
		return 0
	fi
	if ppd_running && command -v powerprofilesctl >/dev/null; then
		case "$want" in
			performance) want=performance ;;
			balanced)    want=balanced ;;
			quiet|low-power) want=power-saver ;;
		esac
		powerprofilesctl set "$want" 2>/dev/null || { warn "could not set profile '$want'"; return 1; }
	else
		local f
		f=$(echo /sys/class/platform-profile/*/profile)
		[[ -e "$f" ]] || { warn "no platform profile node"; return 1; }
		echo "$want" > "$f" 2>/dev/null || { warn "could not write $f (need root?)"; return 1; }
	fi
	return 0
}

# Only CPU package and dGPU drive the decision.
#
# Deliberately NOT a max() over every hwmon sensor, because acer-wmi's
# temp3_input is unusable on this model. Per acer-wmi.c the three channels are:
#   temp1 = ACER_WMID_SENSOR_CPU_TEMPERATURE
#   temp2 = ACER_WMID_SENSOR_GPU_TEMPERATURE
#   temp3 = ACER_WMID_SENSOR_EXTERNAL_TEMPERATURE_2
# temp3 is a defined channel, but the PH315-54's EC returns a fixed placeholder:
# measured flat at 83C (+/-2) while fan speed swung 1538->5660 rpm and CPU/GPU
# fell 4C. A blind max() is dominated by it and pins the machine to
# `performance` forever. nvme/wifi are excluded too: they run warm and
# shouldn't drive laptop fans.

cpu_temp() {
	local v
	# Prefer coretemp's "Package id 0"; fall back to the x86_pkg_temp zone.
	for l in /sys/class/hwmon/hwmon*/temp*_label; do
		[[ -r "$l" ]] || continue
		if [[ "$(cat "$l" 2>/dev/null)" == "Package id 0" ]]; then
			v=$(cat "${l%_label}_input" 2>/dev/null) && { echo $(( v / 1000 )); return; }
		fi
	done
	for z in /sys/class/thermal/thermal_zone*; do
		if [[ "$(cat "$z/type" 2>/dev/null)" == "x86_pkg_temp" ]]; then
			v=$(cat "$z/temp" 2>/dev/null) && { echo $(( v / 1000 )); return; }
		fi
	done
	echo 0
}

gpu_temp() {
	local v
	if command -v nvidia-smi >/dev/null 2>&1; then
		v=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
		[[ "$v" =~ ^[0-9]+$ ]] && { echo "$v"; return; }
	fi
	# Fallback: acer-wmi temp2 tracks the dGPU on this model.
	v=$(cat /sys/devices/platform/acer-wmi/hwmon/hwmon*/temp2_input 2>/dev/null | head -1)
	[[ "$v" =~ ^[0-9]+$ ]] && { echo $(( v / 1000 )); return; }
	echo 0
}

# Hottest of the two sensors we actually trust.
max_temp() {
	local c g
	c=$(cpu_temp); g=$(gpu_temp)
	(( c >= g )) && echo "$c" || echo "$g"
}

install_unit() {
	[[ "$EUID" -eq 0 ]] || exec sudo "$SELF" --install
	cat > "$UNIT_PATH" <<EOF
[Unit]
Description=Acer Predator temperature-driven power profile switching
After=power-profiles-daemon.service
Wants=power-profiles-daemon.service

[Service]
Type=simple
Environment=FAN_HOT=${HOT}
Environment=FAN_COOL=${COOL}
Environment=FAN_INTERVAL=${INTERVAL}
ExecStart=${SELF}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable --now acer-fan-curve.service
	echo "installed and started: $UNIT_PATH"
	systemctl --no-pager --lines=5 status acer-fan-curve.service || true
}

uninstall_unit() {
	[[ "$EUID" -eq 0 ]] || exec sudo "$SELF" --uninstall
	systemctl disable --now acer-fan-curve.service 2>/dev/null || true
	rm -f "$UNIT_PATH"
	systemctl daemon-reload
	echo "removed $UNIT_PATH"
}

for arg in "$@"; do
	case "$arg" in
		--dry-run)   DRY_RUN=1 ;;
		--once)      ONCE=1 ;;
		--install)   install_unit; exit 0 ;;
		--uninstall) uninstall_unit; exit 0 ;;
		-h|--help)
			sed -n '2,/^[^#]/p' "$0" | sed '/^[^#]/d; s/^# \{0,1\}//'
			exit 0 ;;
		*) die "unknown argument: $arg (try --help)" ;;
	esac
done

(( COOL < HOT )) || die "FAN_COOL ($COOL) must be below FAN_HOT ($HOT) for hysteresis"
[[ -n "$(get_profile)" ]] || die "no platform profile available — run acer-predator-v4.sh first"

msg "starting: hot>=${HOT}C -> ${HOT_PROFILE}, cool<=${COOL}C -> ${COOL_PROFILE}, every ${INTERVAL}s"
msg "backend: $(ppd_running && echo power-profiles-daemon || echo 'direct sysfs')"

# Tracks the profile we last set, so a manual change by the user is detectable
# and we don't stomp on it until temps next cross a threshold.
ours=""

while :; do
	temp=$(max_temp)
	cur=$(get_profile)
	(( temp > 0 )) || { warn "no usable temperature reading; skipping"; sleep "$INTERVAL"; continue; }

	if [[ -n "$ours" && "$cur" != "$ours" ]]; then
		msg "profile changed externally ($ours -> $cur); yielding to manual control"
		ours=""
	fi

	if (( temp >= HOT )) && [[ "$cur" != "performance" ]]; then
		msg "${temp}C >= ${HOT}C: -> ${HOT_PROFILE}"
		set_profile "$HOT_PROFILE" && ours=$(get_profile)
	elif (( temp <= COOL )) && [[ "$cur" == "performance" && -n "$ours" ]]; then
		msg "${temp}C <= ${COOL}C: -> ${COOL_PROFILE}"
		set_profile "$COOL_PROFILE" && ours=$(get_profile)
	fi

	(( ONCE )) && { msg "--once: done (temp=${temp}C, profile=${cur})"; exit 0; }
	sleep "$INTERVAL"
done
