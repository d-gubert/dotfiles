# Shared helpers for the monitor profile scripts. Sourced, never executed.
#
# EDID parsing and layout arithmetic live here so the save and apply paths cannot
# drift: they have to agree on how a monitor is identified and where a panel sits,
# or a saved profile will not reproduce what was saved.

# Emit "<output> <edid-hex>" for every connected output, in one xrandr pass.
read_outputs() {
	xrandr --query --verbose | awk '
		/^[^ \t]/ {
			out = ($2 == "connected") ? $1 : ""
			collecting = 0
			next
		}
		out != "" && /^[ \t]+EDID:/ { collecting = 1; next }
		collecting {
			if ($0 ~ /^[ \t]+[0-9a-fA-F]+[ \t]*$/) {
				hex = $0
				gsub(/[^0-9a-fA-F]/, "", hex)
				edid[out] = edid[out] hex
			} else {
				collecting = 0
			}
		}
		END { for (o in edid) print o, edid[o] }
	'
}

# Emit "<output> <WxH+X+Y|off> <rate|-> <primary|->" for every connected output.
# The active mode is the one xrandr stars; a rate can appear more than once in a
# row, so the starred field is picked rather than the first match.
read_geometry() {
	xrandr --query | awk '
		/^[^ \t]/ {
			if (out != "") print out, geo, rate, prim
			out = ""; geo = "off"; rate = "-"; prim = "-"
			if ($2 == "connected") {
				out = $1
				for (i = 3; i <= NF; i++) {
					if ($i == "primary") prim = "primary"
					if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) geo = $i
				}
			}
			next
		}
		out != "" && /\*/ {
			for (i = 2; i <= NF; i++)
				if ($i ~ /\*/) { r = $i; gsub(/[*+]/, "", r); rate = r; break }
		}
		END { if (out != "") print out, geo, rate, prim }
	'
}

# Manufacturer id + product code: EDID bytes 8-11, i.e. hex chars 17-24. This is
# model-level identity, which is the granularity we want -- two units of the same
# model should get the same layout.
edid_model_id() { printf '%s' "${1:16:8}"; }

# The 0xFC descriptor carries the monitor's name, when the vendor sets one. Four
# 18-byte descriptors start at byte 54; a monitor descriptor opens with 00 00 00
# then its tag, and the text runs to a 0x0a terminator or the end of the block.
edid_monitor_name() {
	local edid="$1" block text hex chr i c

	for i in 108 144 180 216; do
		block="${edid:$i:36}"
		[ "${#block}" -eq 36 ] || continue
		[ "${block:0:6}" = "000000" ] || continue
		[ "${block:6:2}" = "fc" ] || continue

		text=""
		for ((c = 10; c < 36; c += 2)); do
			hex="${block:$c:2}"
			[ "$hex" = "0a" ] && break
			printf -v chr '%b' "\\x$hex"
			text+="$chr"
		done

		# Vendors pad the field with spaces.
		text="${text%"${text##*[![:space:]]}"}"
		[ -n "$text" ] || return 1
		printf '%s' "$text"
		return 0
	done

	return 1
}

mode_width() { printf '%s' "${1%x*}"; }
mode_height() { printf '%s' "${1#*x}"; }

# "<X>x<Y>" -> "<X> <Y>". Returns non-zero on anything that is not a position.
parse_position() {
	case "$1" in
		[0-9]*x[0-9]*) printf '%s %s\n' "${1%x*}" "${1#*x}" ;;
		*) return 1 ;;
	esac
}

# Plain-language summary of where the laptop sits relative to the external, for
# the comment a profile carries. Purely descriptive: the coordinates are what
# actually get applied, this only makes them readable at a glance.
describe_placement() {
	local ex="$1" ey="$2" ew="$3" eh="$4" lx="$5" ly="$6" lw="$7" lh="$8"
	local dx dy axis align delta

	dx=$(( (lx + lw / 2) - (ex + ew / 2) ))
	dy=$(( (ly + lh / 2) - (ey + eh / 2) ))

	if [ "${dy#-}" -ge "${dx#-}" ]; then
		[ "$dy" -ge 0 ] && axis="below" || axis="above"
		delta=$dx
		if [ "${delta#-}" -le 1 ]; then
			align="horizontally centred"
		elif [ "$lx" -eq "$ex" ]; then
			align="left edges aligned"
		elif [ $(( lx + lw )) -eq $(( ex + ew )) ]; then
			align="right edges aligned"
		else
			align="${delta#-} px $([ "$delta" -ge 0 ] && echo right || echo left) of centre"
		fi
	else
		[ "$dx" -ge 0 ] && axis="right of" || axis="left of"
		delta=$dy
		if [ "${delta#-}" -le 1 ]; then
			align="vertically centred"
		elif [ "$ly" -eq "$ey" ]; then
			align="top edges aligned"
		elif [ $(( ly + lh )) -eq $(( ey + eh )) ]; then
			align="bottom edges aligned"
		else
			align="${delta#-} px $([ "$delta" -ge 0 ] && echo below || echo above) centre"
		fi
	fi

	printf '%s the external, %s\n' "$axis" "$align"
}
