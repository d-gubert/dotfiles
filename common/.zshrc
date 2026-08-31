# Add deno completions to search path
if [[ ":$FPATH:" != *":$HOME/.zsh/completions:"* ]]; then export FPATH="$HOME/.zsh/completions:$FPATH"; fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Home binaries
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# cargo binaries (rust)
export PATH=$HOME/.cargo/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	copybuffer
	copyfile
	copypath
	gh
	git 
	z 
	zsh-autopair
	zsh-autosuggestions 
	zsh-syntax-highlighting 
)

# Don't load vim mode if running from Neovim terminal
if [[ ! -n $NVIM ]]; then
	plugins+=(zsh-vi-mode)
fi

# UNDO MISTAKE IN BUFFER LINE/PROMPT
bindkey '^[z' undo
bindkey '^[r' redo

source $ZSH/oh-my-zsh.sh

# I don't want shared history
setopt NO_SHARE_HISTORY
# Don't save to history any command lines starting with a white space 
setopt HIST_IGNORE_SPACE
# Don't expand history expressions before executing the command line
setopt NO_HIST_VERIFY
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Change XDG_CACHE_HOME due to home encryption limitations (defined in .xprofile)
# [ -f ~/.xprofile ] && source ~/.xprofile

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
# 	export EDITOR='vi'
# else
# 	export EDITOR='nvim'
# fi

export EDITOR='nvim'

export SUDO_EDITOR="$(which $EDITOR)"
export ZVM_VI_EDITOR=$EDITOR

if [[ "$(uname)" == "Darwin" ]]; then
	BREW_PREFIX="/opt/homebrew"
else
	BREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

BREW_BIN="$BREW_PREFIX/bin/brew"

if [[ -x "$BREW_BIN" ]]; then
	eval "$($BREW_BIN shellenv)"
fi

# OS-specific overrides — shipped by the ubuntu/ or mac/ stow package.
# Defines OPEN_CMD and CLIP_CMD, plus any per-OS PATH entries.
[[ -r ~/.zshrc.os ]] && source ~/.zshrc.os

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Custom functions
#
# Functionality that can't live in a standalone script to be executed.
# Maybe move to a sourced script in the future?

# Switch git worktrees
function gwl() {
	local target
	local filter="${1}"

	if [ -n "${filter}" ]; then
		target=$(
			git worktree list |
			fzf --filter "${filter}" |
			head -1 |
			awk '{ print $1 }'
		) || return

		echo "Changing working directory to ${target}"
	else
		target=$(
			git worktree list |
			fzf --prompt='Worktree > ' --height=~15 --layout=reverse --border --cycle |
			awk '{ print $1 }'
		) || return
	fi

	if [[ -z "${target}" ]]; then
		return 1;
	fi

	if [[ -n $HERDR_ENV ]]; then
		herdr worktree open --path "${target}" --focus >/dev/null 2>&1
		if [[ $? -eq 0 ]]; then
			return 0
		fi
	fi
	
	cd "${target}"
}

# List my open PRs
function mypr() {
	gh search prs --author '@me' --state open --sort updated --order desc --json repository,number,state,title,updatedAt,url \
		--jq '.[] | [.url,.repository.nameWithOwner,("#"+(.number|tostring)),.state,.title,.updatedAt] | @tsv' |
	column -t -s $'\t' |
	fzf --prompt='PR > ' --height=~100% --layout=reverse --with-nth=2.. --accept-nth=1 --border --cycle \
		--header=$'\n[ENTER]/[CTRL-O] Open | [CTRL-Y] Copy to clipboard\n\n' \
		--bind "enter:execute($OPEN_CMD {1})+accept" \
		--bind "ctrl-o:execute-silent($OPEN_CMD {1})" \
		--bind "ctrl-y:execute-silent(echo {1} | $CLIP_CMD)" \
		2>&1 >/dev/null
}

# Claude code dev-tools
function ccd() {
	local profile="~/.claude"
	local port=3456
	local volume
	local detached=false

	while (( $# )); do
		case "$1" in
			-p|--profile)
				shift
				profile="$1"
				;;
			-e|--port) # -e as in "expose port"
				shift
				port="$1"
				;;
			-v|--volume)
				shift
				volume="$1"
				;;
			-d|--detached)
				detached=true
				;;
			*)
				print -u2 "Unknown option or argument: $1"
				print "Fuck you"
				return 10;
				;;
		esac
		shift
	done

	if [[ -n "$volume" ]]; then
		if ! docker volume inspect "$volume" >/dev/null 2>&1; then
			print "Volume not found: $volume";
			print "Fuck you"
			return 21
		fi
		profile=
	fi

	if [[ -n "$profile" ]]; then
		if [[ "$profile[1]" != "/" ]]; then
			profile=${~profile}
		fi

		if [[ ! -d $profile ]]; then
			print "Profile directory not found: $profile"
			print "Fuck you"
			return 22
		fi
	fi

	if [[ -z $volume && -z $profile ]]; then
		print "You gotta give me some Claude directory or volume to work with, bucko"
		print "We all have our limitations"
		return 20
	fi

	local -a flags
	if $detached; then
		flags=(-d)
	fi

	# Image is not published in the registry, needs to be built locally - https://github.com/matt1398/claude-devtools
	docker run --rm -e NODE_ENV=development -p "${port}:3456" -v "${profile:-$volume}:/data/.claude:ro" "${flags[@]}" claude-devtools
}

# Claude code sniffly analytics
function sniffly() {
	local profile="~/.claude"
	local port=8081
	local volume
	local cache="sniffly-cache"
	local detached=true

	while (( $# )); do
		case "$1" in
			-p|--profile)
				shift
				profile="$1"
				;;
			-e|--port) # -e as in "expose port"
				shift
				port="$1"
				;;
			-v|--volume)
				shift
				volume="$1"
				;;
			-c|--cache)
				shift
				cache="$1"
				;;
			-d|--detached)
				detached=true
				;;
			--no-cache)
				cache=
				;;
			*)
				print -u2 "Unknown option or argument: $1"
				print "Fuck you"
				return 10;
				;;
		esac
		shift
	done

	if [[ -n "$volume" ]]; then
		if ! docker volume inspect "$volume" >/dev/null 2>&1; then
			print "Volume not found: $volume";
			print "Fuck you"
			return 22
		fi
		profile=
	fi

	if [[ -n "$profile" ]]; then
		if [[ "$profile[1]" != "/" ]]; then
			profile=${~profile}
		fi

		if [[ ! -d $profile ]]; then
			print "Profile directory not found: $profile"
			print "Fuck you"
			return 21
		fi
	fi

	if [[ -z $volume && -z $profile ]]; then
		print "You gotta give me some Claude directory or volume to work with, bucko"
		print "We all have our limitations"
		return 20
	fi

	# Image is not published in the registry - build it from containers/sniffly
	if ! docker image inspect sniffly >/dev/null 2>&1; then
		print "Image not found: sniffly - attempting build"
		docker build -t sniffly $DOTFILES_PATH/containers/sniffly

		if [[ $? -ne 0 ]]; then
			print "Could not build the sniffly image"
			return 30
		fi
	fi

	# Array, not ${cache:+...}: zsh doesn't word-split parameter expansions, so
	# the flag and its value would arrive as one mangled argument.
	# The cache volume keeps parsed logs between runs - without it every start
	# re-chews through every project from scratch.
	local -a cache_mount
	if [[ -n "$cache" ]]; then
		cache_mount=(-v "${cache}:/home/sniffly/.sniffly")
	fi

	if $detached; then
		cache_mount+=(-d)
	fi

	# Sniffly hardcodes ~/.claude/projects, so the mount target is not negotiable
	docker run --rm -p "${port}:8081" \
		-v "${profile:-$volume}:/home/sniffly/.claude:ro" \
		"${cache_mount[@]}" \
		sniffly
}

function void() { "$@" >/dev/null 2>&1 }
function exists() { void command -v "$1" }

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias pclaude='CLAUDE_CONFIG_DIR=~/.claude-personal claude'

# Home dir encryption long file restriction messes up with this too
# export PLAYWRIGHT_BROWSERS_PATH=/work/.cache/playwright

# Prompt expansion that prints the current script name, then: 
#	- resolves it to absolute path `:A` (following symlinks)
#	- goes 1 directory above twice `:h` ("head" filter, effectively dirname)
export DOTFILES_PATH=${${(%):-%N}:A:h:h}
export DOTFILES_SCRIPTS="${DOTFILES_PATH}/scripts"

export PATH=$DOTFILES_SCRIPTS:$PATH

# ~/.zshrc — disable Powerlevel10k when Cursor Agent runs
if [[ -z "$CURSOR_AGENT" ]]; then
	# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
	#
	# The prompt has two profiles. `wide` is ~/.p10k.zsh alone. `narrow` adds
	# ~/.p10k-narrow.zsh on top of it: one segment line, one command line, no
	# frame. Below this many columns the shell picks `narrow`.
	: ${PROMPT_NARROW_COLUMNS:=90}

	# prompt-profile [narrow|wide|auto]
	#   no argument   follow $COLUMNS — this is what the precmd hook does
	#   narrow|wide   hold that profile until you run `prompt-profile auto`
	#   auto          drop the hold and follow $COLUMNS again
	prompt-profile() {
		case $1 in
			narrow|wide) PROMPT_PROFILE_HOLD=$1 ;;
			auto) PROMPT_PROFILE_HOLD= ;;
			'') ;;
			*) print -u2 "prompt-profile: use narrow, wide or auto"; return 1 ;;
		esac

		local want=$PROMPT_PROFILE_HOLD
		if [[ -z $want ]]; then
			if (( COLUMNS < PROMPT_NARROW_COLUMNS )); then want=narrow; else want=wide; fi
		fi
		[[ $want == "$PROMPT_PROFILE" ]] && return 0

		[[ -r ~/.p10k.zsh ]] || return 1
		source ~/.p10k.zsh
		[[ $want == narrow && -r ~/.p10k-narrow.zsh ]] && source ~/.p10k-narrow.zsh
		typeset -g PROMPT_PROFILE=$want
	}

	prompt-profile
	# Follow the width when it changes, for example when the phone rotates.
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd prompt-profile
fi

# Load pyenv automatically
export PYENV_ROOT="$HOME/.pyenv"

if exists pyenv; then
	export PATH="$PYENV_ROOT/bin:$PATH"
	source <(pyenv init -)
fi

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# Deno Version Manager
export DVM_DIR="$HOME/.dvm"
export PATH="$DVM_DIR/bin:$PATH"

# Golang — /usr/local/go/bin is where the official installer puts the toolchain on
# both Linux and macOS; a brew-installed go is covered by `brew shellenv` instead.
export GOPATH="$HOME/dev/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Carapace
if exists carapace; then
	zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
	source <(carapace _carapace)
fi

if exists jiratui; then
	alias jira="jiratui ui"
fi

if exists lazygit; then
	source <(lazygit completion zsh)
	alias lg='lazygit'
	alias lgs='lazygit stash'
	alias lgl='lazygit log'
fi

if exists lazyjira; then
	alias lj='lazyjira'
fi

# playerctl daemon
if exists playerctld; then
	playerctld daemon 2> /dev/null
fi

if exists zellij; then
	local zcomp="$HOME/.config/zellij/compdef"
	# zellij setup --generate-completion zsh > $zcomp
	fpath=($zcomp $fpath)
	# Run command in new pane
	function zr () { zellij run --name "$*" -- zsh -ic "$*";}
	# Run command in new floating pane
	function zrf () { zellij run --name "$*" --floating -- zsh -ic "$*";}
	# Run command in current pane
	function zri () { zellij run --name "$*" --in-place -- zsh -ic "$*";}
	# Edit file in new pane
	function ze () { zellij edit "$*";}
	# Edit file in new floating pane
	function zef () { zellij edit --floating "$*";}
	# Edit file in current pane
	function zei () { zellij edit --in-place "$*";}
fi

if exists docker; then
	alias dps='docker ps'
	alias dpsa='docker ps -a'
	alias drrm='docker run --rm -it'
	alias dc='docker compose'
	alias dclf='docker compose logs --follow --tail 5'
	alias dcls='docker compose ls'
	alias dcup='docker compose up -d'
	alias dcstop='docker compose stop'
	alias dcdown='docker compose down'
fi

if exists difft; then
	alias gds='git -c diff.external=difft diff'
fi

# Claude Code telemetry -> the local observability stack.
#
# containers/observability/README.md documents the same variables for
# ~/.claude/settings.json. Here instead, because a shell that starts before the
# stack does exports nothing, and a `claude` with a dead collector retries the
# export every OTEL_METRIC_EXPORT_INTERVAL and logs each failure.
#
# The trade of that: a shell already open when the stack comes up does not pick
# the variables up. Re-source this file, or open a new shell.
if exists claude; then
	# ztcp, not `docker ps`: the builtin probe of the collector's published port
	# costs no fork, and a docker call at every shell start is 100ms+ of latency
	# on the prompt. A closed loopback port refuses at once, so there is nothing
	# to time out on.
	zmodload -F zsh/net/tcp b:ztcp 2>/dev/null

	if (( $+builtins[ztcp] )) && ztcp 127.0.0.1 4317 2>/dev/null; then
		ztcp -c $REPLY

		export CLAUDE_CODE_ENABLE_TELEMETRY=1
		export OTEL_METRICS_EXPORTER=otlp
		# The event records — one per prompt, tool call and API request — which
		# the collector routes to Loki. Off by default in Claude Code, and
		# without it the metrics counters are all this stack ever sees.
		#
		# What the events CONTAIN is a separate set of switches, all off:
		# OTEL_LOG_USER_PROMPTS, OTEL_LOG_ASSISTANT_RESPONSES,
		# OTEL_LOG_TOOL_DETAILS and OTEL_LOG_RAW_API_BODIES. Left off, an event
		# says a prompt happened and how big it was; turned on, it carries the
		# text. Local disk either way — the choice is whether prompt and file
		# content lands in a log store that keeps it forever.
		export OTEL_LOGS_EXPORTER=otlp
		# Spans, which the collector routes to Tempo: one
		# `claude_code.interaction` per prompt, with the API calls and tool calls
		# nested under it. Two variables and not one — the exporter alone does
		# nothing while the beta flag is off, and the flag alone produces spans
		# that go nowhere.
		export OTEL_LOG_TOOL_DETAILS=1
		#
		# Redaction is separate again, and shares the OTEL_LOG_* switches above:
		# off, a span still carries tool_name, model, token counts and every
		# duration. What it drops is the prompt text, the command string and the
		# file path.
		export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
		export OTEL_TRACES_EXPORTER=otlp
		export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
		# The published port, not `otel-collector:4317` — that name only resolves
		# inside the observability network.
		export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317
		# Claude Code defaults to delta and Prometheus counters are cumulative.
		# The collector converts, so delta works — but the sender's own running
		# total survives a collector restart and a reconstructed one does not.
		export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
		export OTEL_METRIC_EXPORT_INTERVAL=10000
		# Separates the host from a devbox container in every query.
		export OTEL_RESOURCE_ATTRIBUTES=workspace=host
	fi
fi

if exists tmux; then
	source $DOTFILES_SCRIPTS/lib/tmux-helpers.sh
fi

if exists vi-mongo; then
	alias mvi='vi-mongo'
fi

#Glow suggestions
if exists glow; then
	source <(glow completion zsh)
fi

# Helm suggestions
if exists helm; then
	source <(helm completion zsh)
fi

# Kubectl suggestions
if exists kubectl; then
	source <(kubectl completion zsh)
	alias k=kubectl
fi

# Github CLI tool completion
if exists gh; then
	source <(gh completion -s zsh)
	alias prvw='gh pr view --web'
	alias prv='gh pr view'
	alias prco='gh pr checkout'
	alias prcn='gh pr create --draft'
	alias praction='gh pr checks --watch'
	alias repovw='gh repo view --web'
fi

# Identification for self signed certificates via mkcert
if exists mkcert; then
	export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"
fi

if exists devcontainer; then
	alias dv='devcontainer'
	alias dvup='devcontainer up'
	alias dvex='devcontainer exec'
	alias dvclaude='HERDR_AGENT=claude devcontainer exec claude --dangerously-skip-permissions'
	alias dvshell='devcontainer exec zsh'
fi

if exists eza; then
	alias lt='eza -lhT'
	alias l='eza -lah'
fi

if exists herdr; then
	source <(herdr completion zsh)

	# notify '<command|pipeline>'   — quote the whole pipeline
	#   notify 'make build'
	#   notify 'grep foo big.log | sort | uniq -c'
	# notify '<command|pipeline>'   or   notify <<'EOF' ... EOF
	function notify() {
		emulate -L zsh
		setopt pipe_fail

		local cmd

		if (( $# )); then
			cmd="$*"
		else
			cmd="$(cat)"                                  # heredoc / piped stdin
		fi

		[[ -z ${cmd//[[:space:]]/} ]] && { print -u2 "notify: nothing to run"; return 2 }

		local summary=${cmd//[[:space:]]##/ }           # collapse whitespace/newlines to single spaces
		summary=${summary## }                           # trim leading space
		(( ${#summary} > 120 )) && summary="${summary[1,117]}…"   # cap length for the toast

		local label=${${(z)cmd}[1]:t}                   # first word, basename → sidebar row
		label=${label//[^a-zA-Z0-9_-]/}                 # sanitize to valid agent-label chars
		[[ -z $label ]] && label=job

		local src=notify

		local in_herdr=0

		[[ $HERDR_ENV == 1 && -n $HERDR_PANE_ID ]] && in_herdr=1

		(( in_herdr )) && herdr pane report-agent "$HERDR_PANE_ID" \
			--source $src --agent $label --state working >/dev/null 2>&1

		herdr pane report-metadata "$HERDR_PANE_ID" --source ${src}-display --token summary=$summary

		eval "$cmd"                                      # synchronous → waits for whole pipeline
		local ret=$?

		if (( in_herdr )); then
			herdr pane report-agent "$HERDR_PANE_ID" --source $src --agent $label --state idle >/dev/null 2>&1
			herdr pane release-agent "$HERDR_PANE_ID" --source $src --agent $label >/dev/null 2>&1
		fi

		if (( ret == 0 )); then
			herdr notification show "✓ $summary"          --sound done    >/dev/null 2>&1
		else
			herdr notification show "✗ $summary ($ret)"   --sound request >/dev/null 2>&1
		fi

		return $ret
	}
fi

# Ubuntu 26.04 (resolute) starts the GUI in Wayland by default, causing Electron based apps to think they should use that backend to render
# But i3 uses x11, so if I don't override the GUI backend when starting those apps they just fail, sometimes silently
if exists lsb_release && test "$DESKTOP_SESSION" = "i3" && test "$(lsb_release -cs)" = "resolute"; then
	alias brave="brave-browser --ozone-platform=x11"
	alias code="code --ozone-platform=x11"
fi

if [ -d $HOME/.opencode/bin ]; then
	export PATH=$HOME/.opencode/bin:$PATH
fi

if [[ -n "$SSH_CONNECTION" ]]; then
	export LANG=en_US.UTF-8
	export LC_CTYPE=en_US.UTF-8
fi

# The plugin will auto execute this zvm_after_init function
function zvm_after_init() {
	if exists fzf; then
		source <(fzf --zsh)
		bindkey '' fzf-cd-widget
		bindkey '' fzf-file-widget
	fi

	# Git aliases that would be overwritten by the git plugin
	alias gw='git worktree'
	alias gl='git pull --autostash'
	alias glr='git pull --rebase --autostash'
	alias grd='git rebase --interactive --update-refs --autostash origin/develop'
	alias grc='git rebase --continue'
	alias grs='git rebase --skip'
	alias gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -D'
}

# [ -f "$DOTFILES_SCRIPTS/watch_rocket.sh" ] && zsh -c "$DOTFILES_SCRIPTS/watch_rocket.sh start" &|
