#!/bin/zsh

cd /home/douglas-gubert/dev/containers/local-mongo

if [[ $1 == "down" ]]; then
	# -v forces removing the volume and network
	docker compose down -v
fi

docker compose up -d mongo
