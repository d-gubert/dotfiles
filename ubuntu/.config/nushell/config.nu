# config.nu
#
# Installed by:
# version = "0.101.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

## Config - using the object syntax changes the whole config, better to do setting by setting

$env.config.show_banner = false
$env.config.buffer_editor = 'nvim'
$env.config.edit_mode = 'vi'
$env.config.render_right_prompt_on_last_line = true
$env.config.history.isolation = true
$env.config.cursor_shape = {
    vi_insert: line,
    vi_normal: blink_block,
}

$env.EDITOR = 'nvim'

## Aliases

alias l = ls -la
alias bat = batcat
alias v = nvim

#### Git

alias g = git
alias gst = git status
alias gco = git checkout
alias gcb = git checkout -b
alias gc = git commit --verbose
alias gca = git commit --amend
alias ga = git add
alias gb = git branch
alias gd = git diff
alias gp = git push
alias glog = git log --oneline --decorate --graph
alias gl = git pull
alias gw = git worktree

def gpsup [] {
    let $branch = git branch --show-current
    git push --set-upstream origin $branch
}

#### Docker

alias d = docker
alias dc = docker compose
alias dv = docker volume
alias dn = docker network
alias di = docker image

def ds [] { docker ps | detect columns }
def dsa [] { docker ps -a | detect columns }

#### Kubernetes

alias k = kubectl

## Sourcing plugins

source ~/.cache/carapace/init.nu

source ~/.zoxide.nu

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
source $"($nu.home-path)/.cargo/env.nu"
