#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <email> <domain1> [domain2 ...]" >&2
    exit 1
fi

EMAIL="$1"
shift

LEGO=/usr/local/bin/lego
LE_PATH=/etc/letsencrypt
WEBROOT=/var/www/_letsencrypt

LEGO_VERSION=$("$LEGO" --version 2>&1 | grep -oP '(?<=version )\d+' | head -1)
if [ "$LEGO_VERSION" != "4" ]; then
    echo "Warning: This script is designed for lego 4.x only (detected major version: ${LEGO_VERSION:-unknown})" >&2
    exit 1
fi

args=()
for domain in "$@"; do
    args+=(--domains="$domain")
done

"$LEGO" \
  --path="$LE_PATH" \
  --email="$EMAIL" \
  --http \
  --http.webroot="$WEBROOT" \
  "${args[@]}" \
  renew --days 30

nginx -t
systemctl reload nginx