#!/bin/env zsh

alias t="tmux"
alias tls="tmux list-sessions"
alias tlsk="tmux list-keys"
alias tlsw="tmux list-windows"
alias tlscm="tmux list-commands"
alias techo="tmux display-message"
alias td="tmux_dump_active"
alias tj="tmux_dump_active | jq"

function tmux_dump_active() {
	tmux display-message -p '
{
	"session":{
		"id":"#{session_id}",
		"name":"#{session_name}"
	},
	"window":{
		"id":"#{window_id}",
		"index":#{window_index},
		"name":"#{window_name}",
		"status_glyph":"#{@status_glyph}"
	},
	"pane":{
		"id":"#{pane_id}",
		"index":#{pane_index},
		"title":"#{pane_title}",
		"command":"#{pane_current_command}",
		"path":"#{pane_current_path}"
	}
}'
}
