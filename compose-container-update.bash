#!/usr/bin/env bash

docker compose pull
docker compose stop
docker compose up -d --force-recreate
