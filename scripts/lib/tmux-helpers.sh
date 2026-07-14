#!/bin/env zsh

alias t="tmux"
alias tls="tmux list-sessions"
alias tlsk="tmux list-keys"
alias tlsw="tmux list-windows"
alias tlscm="tmux list-commands"
alias td="tmux_dump"
alias tj="tmux_dump | jq"

function tmux_dump() {
	tmux display-message -p '
{
	"session":{
		"id":"#{session_id}",
		"name":"#{session_name}",
		"active":#{?session_active,true,false}
	},
	"window":{
		"id":"#{window_id}",
		"index":#{window_index},
		"name":"#{window_name}",
		"active":#{?window_active,true,false},
		"status_glyph":"#{@status_glyph}"
	},
	"pane":{
		"id":"#{pane_id}",
		"index":#{pane_index},
		"title":"#{pane_title}",
		"active":#{?pane_active,true,false},
		"command":"#{pane_current_command}",
		"path":"#{pane_current_path}"
	},
	"hook":{
		"name":"#{hook}",
		"client":"#{hook_client}",
		"pane":"#{hook_pane}",
		"window":"#{hook_window}",
		"session":"#{hook_session}"
	}
}'
}
