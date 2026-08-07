# default

The fallback profile, used by any workspace that no other profile's `match`
claims. `default` never matches by path — it is only ever the fallback.

It is deliberately empty: you get the image's toolchain (Node/Yarn/pnpm through
Volta, which honours a project's own `volta`/`packageManager` pins), the egress
firewall, your Claude Code and `gh` logins, and a shell. Nothing is installed in
the workspace, because nothing is assumed about it — run your own
`yarn install` in there.

Give it an `env`, `ports`, `allowed-domains` or `setup.sh` if you want a default
that applies to every unclaimed repo; see `../README.md` for the contract, and
`../rocketchat/` for a filled-in example.
