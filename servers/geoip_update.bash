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

# -------------------- helpers --------------------

sha256_of() {
    sha256sum "$1" | awk '{print $1}'
}

# Try to fetch remote checksum file; returns 0 and prints hash on success
fetch_remote_sha256() {
    local url="$1"
    local out
    out=$(curl --fail --silent --show-error --location \
               --connect-timeout 10 --max-time 30 \
               "$url" 2>/dev/null) || return 1
    # Accept bare hex hash (possibly followed by filename)
    echo "$out" | awk '{print $1}' | grep -Eq '^[0-9a-fA-F]{64}$' || return 1
    echo "$out" | awk '{print $1}'
}

# -------------------- download & install --------------------

errors=0
updated=0
skipped=0

for db in "${DATABASES[@]}"; do
    url="https://${domain}/${db}"
    tmp_file="${TEMP_DIR}/${db}"
    dest_file="${GEOIP_DIR}/${db}"

    # ---- try remote checksum first (saves bandwidth if unchanged) ----
    remote_hash=""
    if remote_hash=$(fetch_remote_sha256 "https://${domain}/${db}.sha256"); then
        log "Got remote SHA256 for $db: $remote_hash"
        if [ -f "$dest_file" ]; then
            local_hash=$(sha256_of "$dest_file")
            if [ "$local_hash" = "$remote_hash" ]; then
                log "SKIP: $db is already up-to-date (SHA256 match)"
                (( skipped++ )) || true
                continue
            fi
        fi
    fi

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

        # ---- compare hashes: skip replace if file hasn't changed ----
        new_hash=$(sha256_of "$tmp_file")

        if [ -n "$remote_hash" ] && [ "$new_hash" != "$remote_hash" ]; then
            log "ERROR: SHA256 mismatch for $db (expected $remote_hash, got $new_hash)"
            (( errors++ )) || true
            continue
        fi

        if [ -f "$dest_file" ]; then
            old_hash=$(sha256_of "$dest_file")
            if [ "$old_hash" = "$new_hash" ]; then
                log "SKIP: $db is already up-to-date (SHA256 match after download)"
                (( skipped++ )) || true
                continue
            fi
            # Atomic replace: backup old file, move new one in
            cp -f "$dest_file" "${dest_file}.bak"
        fi

        mv -f "$tmp_file" "$dest_file"
        log "Successfully updated $db (SHA256: $new_hash)"
        (( updated++ )) || true
    else
        log "ERROR: Failed to download $db from $url"
        (( errors++ )) || true
    fi
done

# -------------------- result --------------------

if [ "$errors" -gt 0 ]; then
    log "Completed with $errors error(s) | updated: $updated | skipped (unchanged): $skipped"
    exit 1
fi

log "All databases processed: updated $updated, skipped $skipped (already up-to-date)"

exit 0
