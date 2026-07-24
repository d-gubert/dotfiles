#!/usr/bin/env bash
#
# Capture the current display arrangement as a monitor profile.
#
# Arrange the screens however you like (arandr is convenient for this) and set
# the font sizes you want, then run this. It writes a profile that
# apply-monitor-profile.sh restores whenever that monitor is plugged in again.
#
# Usage: save-monitor-profile.sh [-f] [name]
#   -f, --force   overwrite an existing profile
#   name          filename stem; defaults to a slug of the monitor's EDID name

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/monitors.sh
. "$script_dir/lib/monitors.sh"

profile_dir="${XDG_CONFIG_HOME:-$HOME/.config}/i3/monitors"
generated_config="${XDG_CACHE_HOME:-$HOME/.cache}/i3/monitor-display.conf"

log() { printf '[save-monitor] %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

force=0
name=""

while [ $# -gt 0 ]; do
	case "$1" in
		-f|--force) force=1 ;;
		-h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
		-*) die "unknown option $1" ;;
		*) name="$1" ;;
	esac
	shift
done

# "WxH+X+Y" -> gw gh gx gy
parse_geo() {
	local g="$1"
	gw="${g%%x*}"; g="${g#*x}"
	gh="${g%%+*}"; g="${g#*+}"
	gx="${g%%+*}"; gy="${g#*+}"
}

# "DejaVu Sans Mono 8" -> fam="DejaVu Sans Mono" sz="8"
split_font() {
	sz="${1##* }"
	fam="${1% *}"
}

slugify() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
		sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//'
}

# Emit "<output>\t<pango font>" for every bar i3 currently has. This reads the
# live bars rather than the config file, so hand edits are picked up too.
bar_fonts() {
	local ids id cfg font outputs out
	ids="$(i3-msg -t get_bar_config 2>/dev/null | tr -d '[]"' | tr ',' ' ')" || return 0
	for id in $ids; do
		cfg="$(i3-msg -t get_bar_config "$id")"
		font="$(printf '%s' "$cfg" | sed -n 's/.*"font":"pango:\([^"]*\)".*/\1/p')"
		outputs="$(printf '%s' "$cfg" | sed -n 's/.*"outputs":\[\([^]]*\)\].*/\1/p' | tr -d '"' | tr ',' ' ')"
		for out in $outputs; do
			printf '%s\t%s\n' "$out" "$font"
		done
	done
}

font_for_output() {
	# No early `exit`: under pipefail it would SIGPIPE the producer and abort.
	bar_fonts | awk -F'\t' -v o="$1" '$1 == o && !seen { print $2; seen = 1 }'
}

# The effective global font: the generated fragment wins, since it is included
# after the default in the main config.
current_global_font() {
	local f=""
	[ -r "$generated_config" ] && f="$(sed -n 's/^font pango:\(.*\)$/\1/p' "$generated_config" | tail -1)"
	[ -n "$f" ] || f="$(i3-msg -t get_config 2>/dev/null | sed -n 's/^font pango:\(.*\)$/\1/p' | tail -1)"
	printf '%s' "$f"
}

# --- gather -----------------------------------------------------------------

declare -A edid_of geo_of rate_of primary_of

while read -r out edid; do
	edid_of["$out"]="$edid"
done < <(read_outputs)

while read -r out geo rate prim; do
	geo_of["$out"]="$geo"
	rate_of["$out"]="$rate"
	primary_of["$out"]="$prim"
done < <(read_geometry)

laptop=""
externals=()

for out in "${!edid_of[@]}"; do
	case "$out" in
		eDP*|LVDS*) laptop="$out" ;;
		*) [ "${geo_of[$out]}" != off ] && externals+=("$out") ;;
	esac
done

[ -n "$laptop" ] || die "no internal panel found"
[ "${#externals[@]}" -gt 0 ] || die "no active external monitor; connect and enable one first"

# The profile format describes one external plus the laptop, so prefer the
# primary when several are live and say which ones are being left out.
external="${externals[0]}"
for out in "${externals[@]}"; do
	[ "${primary_of[$out]}" = primary ] && external="$out"
done
for out in "${externals[@]}"; do
	[ "$out" = "$external" ] || log "ignoring $out: a profile covers one external plus the laptop"
done

edid="${edid_of[$external]}"
edid_id="$(edid_model_id "$edid")"
monitor_name="$(edid_monitor_name "$edid" || printf 'Monitor %s' "$edid_id")"

parse_geo "${geo_of[$external]}"
ext_mode="${gw}x${gh}" ext_rate="${rate_of[$external]}"
ext_position="${gx}x${gy}"
ext_w=$gw ext_h=$gh ext_x=$gx ext_y=$gy

# --- placement ---------------------------------------------------------------

if [ "${geo_of[$laptop]}" = off ]; then
	lap_position="off"
	lap_mode="" lap_rate="" placement=""
else
	parse_geo "${geo_of[$laptop]}"
	lap_mode="${gw}x${gh}" lap_rate="${rate_of[$laptop]}"
	lap_position="${gx}x${gy}"

	# Only ever a comment in the written profile: the coordinates above are what
	# gets applied, this just says what they look like.
	placement="$(describe_placement \
		"$ext_x" "$ext_y" "$ext_w" "$ext_h" "$gx" "$gy" "$gw" "$gh")"
fi

# --- fonts -------------------------------------------------------------------

split_font "$(current_global_font)"
font_family="$fam" font_size="$sz"

ext_bar_font="$(font_for_output "$external")"
if [ -n "$ext_bar_font" ]; then
	split_font "$ext_bar_font"
	ext_bar_size="$sz"
else
	ext_bar_size="$font_size"
fi

lap_bar_font="$(font_for_output "$laptop")"
if [ -n "$lap_bar_font" ]; then
	split_font "$lap_bar_font"
	lap_bar_size="$sz"
else
	lap_bar_size="$font_size"
fi

# --- write -------------------------------------------------------------------

[ -n "$name" ] || name="$(slugify "$monitor_name")"
[ -n "$name" ] || name="monitor-$edid_id"
target="$profile_dir/$name.conf"

if [ -e "$target" ] && [ "$force" -eq 0 ]; then
	die "$target exists; pass -f to overwrite or give a different name"
fi

physical="$(xrandr --query | awk -v o="$external" '
	$1 == o && !seen { for (i = 1; i < NF; i++) if ($i ~ /mm$/) { print $i " x " $(i+2); seen = 1; break } }')"

mkdir -p "$profile_dir"
{
	printf '# %s -- %s%s\n' "$monitor_name" "$ext_mode" "${physical:+, $physical}"
	printf '# Saved from the live layout by save-monitor-profile.sh on %s.\n' "$(date +%F)"
	printf '#\n'
	printf '# EDID_ID is bytes 8-11 of the EDID: manufacturer id + product code.\n'
	printf 'EDID_ID="%s"\n' "$edid_id"
	printf 'NAME="%s"\n' "$monitor_name"
	printf '\n'
	printf '# The external panel: primary. POSITION is the top-left corner, <X>x<Y>.\n'
	printf 'MODE="%s"\n' "$ext_mode"
	[ "$ext_rate" = "-" ] || printf 'RATE="%s"\n' "$ext_rate"
	printf 'POSITION="%s"\n' "$ext_position"
	printf '\n'
	if [ "$lap_position" = off ]; then
		printf '# The laptop panel: dark while this monitor is connected.\n'
		printf 'LAPTOP_POSITION="off"\n'
	else
		printf '# The laptop panel. Coordinates are applied exactly as written;\n'
		printf '# for reference, this one sits %s.\n' "$placement"
		printf 'LAPTOP_MODE="%s"\n' "$lap_mode"
		[ "$lap_rate" = "-" ] || printf 'LAPTOP_RATE="%s"\n' "$lap_rate"
		printf 'LAPTOP_POSITION="%s"\n' "$lap_position"
	fi
	printf '\n'
	printf '# FONT_SIZE covers the window titles and is the default for both bars;\n'
	printf '# each bar can then differ. Drop a BAR_*_SIZE line to follow FONT_SIZE.\n'
	printf 'FONT_FAMILY="%s"\n' "$font_family"
	printf 'FONT_SIZE="%s"\n' "$font_size"
	printf 'BAR_FONT_SIZE="%s"\n' "$ext_bar_size"
	[ "$placement" = off ] || printf 'LAPTOP_BAR_FONT_SIZE="%s"\n' "$lap_bar_size"
} >"$target"

log "wrote $target"
log "matched on $external (EDID id $edid_id)"
printf '\n'
cat "$target"
