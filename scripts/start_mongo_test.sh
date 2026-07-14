#!/bin/env zsh

compose="$DOTFILES_PATH/containers/local-mongo/docker-compose.yml"

if [[ $1 == "down" ]]; then
	# -v forces removing the volume and network
	docker compose -f "$compose" down -v
fi

docker compose -f "$compose" up -d mongo
