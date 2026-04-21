# env.nu
#
# Installed by:
# version = "0.101.0"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

use std/util "path add"

path add "~/bin"
path add "~/.local/bin"
path add "/home/linuxbrew/.linuxbrew/bin"
path add "/home/linuxbrew/.linuxbrew/sbin"

$env.gopath = "$HOME/dev/go"
path add "/usr/local/go/bin"
path add "$env.gopath/bin"

path add ~/.cargo/bin

## Carapace setup - needs to run before config.nu
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

zoxide init nushell | save -f ~/.zoxide.nu
