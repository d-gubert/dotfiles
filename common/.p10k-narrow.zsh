# Narrow-terminal overlay for Powerlevel10k.
#
# Source this file AFTER ~/.p10k.zsh. It keeps the colors and the icons of the
# main config and changes only the layout, so a small screen — an ssh session
# from a phone, a split tmux pane — keeps room for the command you type.
#
# ~/.zshrc applies it through the prompt-profile function.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Move the command to its own line. The segments no longer take typing space,
  # so the full width of the screen is yours.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir                     # current directory
    vcs                     # git status
    newline                 # start a second line
    prompt_char             # prompt symbol
  )

  # Keep only the segments that report the last command.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
  )

  # No empty line above the prompt. A phone screen is short as well as narrow.
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

  # No ╭─ ├─ ╰─ frame. It costs 2 columns on every prompt line.
  typeset -g POWERLEVEL9K_MULTILINE_{FIRST,NEWLINE,LAST}_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_{FIRST,NEWLINE,LAST}_PROMPT_SUFFIX=

  # Always shorten the directory to the shortest unique prefix: ~/d/dotfiles.
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0

  # Replace the prompt of a finished command with a bare ❯. The scrollback of a
  # small screen stays readable.
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

  # If p10k is already loaded, reload configuration.
  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
