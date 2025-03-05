#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

docker compose pull
docker compose stop
docker compose up -d --force-recreate
