#!/usr/bin/env zsh

local logfile="$XDG_CACHE_HOME/cliphist.log"
local histfile="$XDG_CACHE_HOME/cliphist"
local placeholder="<NEWLINE>"

exec 2>> $logfile

function ch_log() {
	echo $(date +%Y-%m-%dT%H:%M:%SZ) PID:$$ $1 >&2
}

function ch_highlight() {
	clip=$(xclip -o -selection primary | xclip -i -f -selection clipboard 2>/dev/null)
}

function ch_clipboard() {
	res=$(xclip -o -selection clipboard 2>/dev/null)
	if [[ "$clip" != "$res" ]]; then
		clip=$res
		return 0
	fi

	return 1
}

function ch_writeHistory() {
	[ -f "$histfile" ] || notify-send "Creating $histfile"; touch $histfile
	[ -z "$clip" ] && exit 0

	multiline=$(printf '%s' "$clip" | sed ':a;N;$!ba;s/\n/'"$placeholder"'/g')

	# Avoid duplicating the content inside the file
	grep -Fxq "$multiline" "$histfile" || echo "$multiline" >> "$histfile"
}

function ch_editor() {
	local session
	session=$(zellij list-sessions -n 2>/dev/null | grep -v "EXITED" | awk 'NR==1{print $1}')

	if [[ -n "$session" ]]; then
		zellij --session "$session" action edit -f "$histfile"
	else
		alacritty -e $EDITOR "$histfile"
	fi
}

function ch_sel() {
	selection=$(tac "$histfile" | rofi -dmenu -p "Clipboard >" -matching fuzzy -sort \
		-kb-remove-to-eol "" \
		-kb-cancel "Control+c,Escape,Control+g,Control+bracketleft" \
		-kb-accept-entry "Control+m,Return,KP_Enter" \
		-kb-row-up "Control+k,Up,Control+p" \
		-kb-row-down "Control+j,Down,Control+n" \
		-kb-custom-1 "Alt+e")

	local rofi_exit=$?

	if [[ $rofi_exit -eq 10 ]]; then
		ch_editor
	elif [[ -n "$selection" ]]; then
		printf '%s' "$(printf '%s' "$selection" | sed "s/$placeholder/\n/g")" | xclip -i -selection clipboard
		notify-send "Copied to clipboard!"
	fi
}

function ch_checkRunning() {
	ps axww -H -O ppid= | grep '[c]lipnotify' 2&>1 >/dev/null
}

function ch_loop() {
	if ch_checkRunning; then
		ch_log "Another instance identified, returning"
		return
	fi

	while read -r _event; do
		ch_log "Loop start"
		ch_clipboard && ch_writeHistory
		ch_log "Loop end"
	done < <(clipnotify -s "clipboard" -l)
}

if [[ "$1" == "start" ]]; then
	ch_loop
elif [[ "$1" == "sel" ]]; then
	ch_sel
fi

