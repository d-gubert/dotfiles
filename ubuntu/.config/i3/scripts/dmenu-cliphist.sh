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
	ch_log "ch_output $res"
	if [[ "$clip" != "$res" ]]; then
		clip=$res
		return 0
	fi

	return 1
}

function ch_writeHistory() {
	[ -f "$histfile" ] || notify-send "Creating $histfile"; touch $histfile
	[ -z "$clip" ] && exit 0

	multiline=$(echo "$clip" | sed ':a;N;$!ba;s/\n/'"$placeholder"'/g')

	# Avoid duplicating the content inside the file
	grep -Fxq "$multiline" "$histfile" || echo "$multiline" >> "$histfile"
}

function ch_sel() {
	selection=$(tac "$histfile" | rofi -dmenu -p "> ")
	[ -n "$selection" ] && echo "$selection" | sed "s/$placeholder/\n/g" | xclip -i -selection clipboard && notify-send "Copied to clipboard!" ;
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

# case "$1" in
#   add) highlight && write ;;
#   out) output && write ;;
#   sel) sel ;;
#   *) printf "$0 | File: $histfile\n\nadd - copies primary selection to clipboard, and adds to history file\nout - pipe commands to copy output to clipboard, and add to history file\nsel - select from history file with dmenu and recopy!\n" ; exit 0 ;;
# esac
#
# [ -z "$notification" ] || notify-send "$notification"
