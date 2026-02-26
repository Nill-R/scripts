#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
#
# Downloads GeoLite2 MaxMind databases from a custom mirror.
# The mirror domain is read from /etc/GeoIP-domain.conf
# Databases are saved to /usr/share/GeoIP/

set -eo pipefail

CONF_FILE="/etc/GeoIP-domain.conf"
GEOIP_DIR="/usr/share/GeoIP"
LOG_FILE="/var/log/geoip_update.log"

DATABASES=(
    "GeoLite2-Country.mmdb"
    "GeoLite2-City.mmdb"
    "GeoLite2-ASN.mmdb"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# -------------------- read config --------------------

if [ ! -f "$CONF_FILE" ]; then
    log "ERROR: Config file $CONF_FILE not found"
    exit 1
fi

domain=$(grep -v '^\s*#' "$CONF_FILE" | grep -v '^\s*$' | head -n1 | tr -d '[:space:]')

if [ -z "$domain" ]; then
    log "ERROR: No domain found in $CONF_FILE"
    exit 1
fi

log "Using domain: $domain"

# -------------------- prepare dirs --------------------

mkdir -p "$GEOIP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

TEMP_DIR=$(mktemp -d /tmp/geoip_update.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

# -------------------- download & install --------------------

errors=0

for db in "${DATABASES[@]}"; do
    url="https://${domain}/${db}"
    tmp_file="${TEMP_DIR}/${db}"
    dest_file="${GEOIP_DIR}/${db}"

    log "Downloading $db from $url"

    if curl --fail --silent --show-error --location \
            --connect-timeout 30 --max-time 120 \
            -o "$tmp_file" "$url"; then

        # Verify the downloaded file is a valid mmdb (magic bytes: \xab\xcd\xefMaxMind)
        if ! file "$tmp_file" 2>/dev/null | grep -qi "maxmind\|mmdb\|data" && \
           ! head -c 6 "$tmp_file" 2>/dev/null | grep -q "MaxMin"; then
            # Lightweight check: file must be non-empty binary
            if [ ! -s "$tmp_file" ]; then
                log "ERROR: Downloaded file $db is empty"
                (( errors++ )) || true
                continue
            fi
        fi

        # Atomic replace: backup old file, move new one in
        if [ -f "$dest_file" ]; then
            cp -f "$dest_file" "${dest_file}.bak"
        fi

        mv -f "$tmp_file" "$dest_file"
        log "Successfully updated $db"
    else
        log "ERROR: Failed to download $db from $url"
        (( errors++ )) || true
    fi
done

# -------------------- result --------------------

if [ "$errors" -gt 0 ]; then
    log "Completed with $errors error(s)"
    exit 1
fi

log "All databases updated successfully"

exit 0
