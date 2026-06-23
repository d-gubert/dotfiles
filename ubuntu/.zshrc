# Add deno completions to search path
if [[ ":$FPATH:" != *":$HOME/.zsh/completions:"* ]]; then export FPATH="$HOME/.zsh/completions:$FPATH"; fi
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
export PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$HOME/bin:$HOME/.local/bin:$PATH

# cargo binaries (rust)
export PATH=$HOME/.cargo/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# Cursor dislikes p10k for some reason
if [[ -z $CURSOR_CLI_MODE ]]; then
	ZSH_THEME="powerlevel10k/powerlevel10k"
fi

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

source $ZSH/oh-my-zsh.sh

# I don't want shared history
setopt NO_SHARE_HISTORY
setopt HIST_IGNORE_SPACE

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Change XDG_CACHE_HOME due to home encryption limitations (defined in .xprofile)
[ -f ~/.xprofile ] && source ~/.xprofile

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
	export EDITOR='vi'
else
	export EDITOR='nvim'
fi

export SUDO_EDITOR="$(which $EDITOR)"
export ZVM_VI_EDITOR=$EDITOR

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Custom functions
#
# Functionality that can't live in a standalone script to be executed.
# Maybe move to a sourced script in the future?

# Switch git worktrees
gwl() {
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

	[[ -n "${target}" ]] && cd "${target}"
}

# List my open PRs
mypr() {
	gh search prs --author '@me' --state open --sort updated --order desc --json repository,number,state,title,updatedAt,url \
		--jq '.[] | [.url,.repository.nameWithOwner,("#"+(.number|tostring)),.state,.title,.updatedAt] | @tsv' |
	column -t -s $'\t' |
	fzf --prompt='PR > ' --height=~100% --layout=reverse --with-nth=2.. --accept-nth=1 --border --cycle \
		--header=$'\n[ENTER]/[CTRL-O] Open | [CTRL-Y] Copy to clipboard\n\n' \
		--bind 'enter:execute(xdg-open {1})+accept' \
		--bind 'ctrl-o:execute-silent(xdg-open {1})' \
		--bind 'ctrl-y:execute-silent(echo {1} | xclip -selection clipboard)' \
		2>&1 >/dev/null
}

# Claude code dev-tools
ccd() {
	local profile="~/.claude"
	local port=3456

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
			*)
				print -u2 "Unknown option or argument: $1"
				print "Fuck you"
				return 1;
				;;
		esac
		shift
	done

	if [[ "$profile[1]" != "/" ]]; then
		profile=${~profile}
	fi

	if [[ ! -d $profile ]]; then
		print "Profile directory not found: $profile"
		print "Fuck you"
		return 1
	fi

	# Image is not published in the registry, needs to be built locally - https://github.com/matt1398/claude-devtools
	docker run --rm -e NODE_ENV=development -p "${port}:3456" -v "$profile:/data/.claude:ro" claude-devtools
}

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias gw='git worktree'

# Home dir encryption long file restriction messes up with this too
export PLAYWRIGHT_BROWSERS_PATH=/work/.cache/playwright

# Prompt expansion that prints the current script name, then resolves it to absolute path `:A` (following symlinks)
export DOTFILES_PATH=$(dirname ${${(%):-%N}:A})
export DOTFILES_SCRIPTS="${DOTFILES_PATH}/scripts"

export PATH=$DOTFILES_SCRIPTS:$PATH

if command -v jiratui >/dev/null; then
	alias jira="jiratui ui"
fi

if command -v lazygit >/dev/null; then
	source <(lazygit completion zsh)
	alias lg='lazygit'
	alias lgs='lazygit stash'
	alias lgl='lazygit log'
fi

if command -v lazyjira >/dev/null; then
	alias lj='lazyjira'
fi

# ~/.zshrc — disable Powerlevel10k when Cursor Agent runs
if [[ -n "$CURSOR_AGENT" ]]; then
	# Skip theme initialization for better compatibility
else
	# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
	[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# Load pyenv automatically
export PYENV_ROOT="$HOME/.pyenv"

if command -v pyenv >/dev/null; then
	export PATH="$PYENV_ROOT/bin:$PATH"
	source <(pyenv init -)
fi

# Deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# Deno Version Manager
export DVM_DIR="$HOME/.dvm"
export PATH="$DVM_DIR/bin:$PATH"

# Golang
export GOPATH="$HOME/dev/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# Carapace
if command -v carapace >/dev/null; then
	zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
	source <(carapace _carapace)
fi

# playerctl daemon
if command -v playerctld >/dev/null; then
	playerctld daemon 2> /dev/null
fi

# Zellij
if command -v zellij >/dev/null; then
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

# Helm suggestions
if command -v helm >/dev/null; then
	source <(helm completion zsh)
fi

# Kubectl suggestions
if command -v kubectl >/dev/null; then
	source <(kubectl completion zsh)
	alias k=kubectl
fi

# Github CLI tool completion
if command -v gh >/dev/null; then
	source <(gh completion -s zsh)
	alias prvw='gh pr view --web'
	alias prv='gh pr view'
	alias praction='gh pr checks --watch'
	alias prco='gh pr checkout'
	alias repovw='gh repo view --web'
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Identification for self signed certificates via mkcert
if command -v mkcert >/dev/null; then
	export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"
fi

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# The plugin will auto execute this zvm_after_init function
function zvm_after_init() {
	if command -v fzf >/dev/null; then
		source <(fzf --zsh)
	fi
}

[ -f "$DOTFILES_SCRIPTS/watch_rocket.sh" ] && zsh -c "$DOTFILES_SCRIPTS/watch_rocket.sh start" &|

###### TESTING DENO ######

# function deno () {
# 	DIR=${DENO_DIR:-$HOME/.deno}
# 	echo "DOCKER DENO - $@ - \$DENO_DIR is $DIR"
# 	docker run \
# 		--interactive \
# 		--tty \
# 		--rm \
# 		--volume /work:/work \
# 		--volume $DIR:/deno-dir \
# 		--workdir $PWD \
# 		--entrypoint deno \
# 		custom-deno \
# 		"$@"
# }
