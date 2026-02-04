#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

set -eo pipefail

DEFAULT_DAYS=32
DAYS_BEFORE_EXPIRY="$DEFAULT_DAYS"

display_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  -c, --config PATH   Specify custom config path"
    echo "  -d, --days DAYS     Renew certificates if expiring in DAYS (default: $DEFAULT_DAYS)"
    echo "  -h, --help          Display this help message"
}

log() {
    local message="$1"
    local log_file="/var/log/lego/lego_cert.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$log_file"
}

check_var() {
    if [ -z "${!1}" ]; then
        log "ERROR: $1 is not set in the configuration file"
        return 1
    fi
}

# shellcheck source=/dev/null
safe_source() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log "ERROR: Configuration file $file not found"
        return 1
    fi

    if grep -q $'\r' "$file"; then
        log "WARNING: $file contains CRLF, converting"
        local tmp
        tmp=$(mktemp)
        tr -d '\r' < "$file" > "$tmp"
        source "$tmp"
        rm -f "$tmp"
    else
        source "$file"
    fi
}

is_directory_empty() {
    [ -z "$(ls -A "$1" 2>/dev/null)" ]
}

process_domain() {
    local domain="$1"
    local ca="$2"
    local cert_path="$3"
    local action="run"

    if [ -d "$cert_path" ] && ! is_directory_empty "$cert_path"; then
        action="renew"
    else
        mkdir -p "$cert_path"
    fi

    export LEGO_DISABLE_CNAME_SUPPORT=true

    local ca_args=()
    local domain_args=()

    case "$ca" in
        LetsEncrypt)
            domain_args+=(--domains "*.$domain" --domains "$domain")
            ;;
        ZeroSSL)
            ca_args+=(
                --server https://acme.zerossl.com/v2/DV90
                --eab
                --kid "$ZEROSSL_EAB_KID"
                --hmac "$ZEROSSL_EAB_HMAC_KEY"
            )
            domain_args+=(--domains "*.$domain" --domains "$domain")
            ;;
        *)
            log "ERROR: Unknown CA $ca"
            return 1
            ;;
    esac

    local cmd=(
        "$LEGO"
        "${ca_args[@]}"
        --dns "$DNS_PROVIDER"
        --email "$EMAIL"
        --path "$cert_path"
        --accept-tos
        "${domain_args[@]}"
    )

    if [ "$action" = "renew" ]; then
        cmd+=(renew --days "$DAYS_BEFORE_EXPIRY")
    else
        cmd+=(run)
    fi

    log "Processing $domain via $ca ($action)"

    if ! "${cmd[@]}"; then
        log "ERROR: Failed to $action certificate for $domain with $ca"
        return 1
    fi

    log "Successfully processed $domain with $ca"
}

# -------------------- args --------------------

CONF_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONF_PATH="$2"
            shift 2
            ;;
        -d|--days)
            DAYS_BEFORE_EXPIRY="$2"
            shift 2
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            display_usage
            exit 1
            ;;
    esac
done

if ! [[ "$DAYS_BEFORE_EXPIRY" =~ ^[0-9]+$ ]]; then
    log "ERROR: --days must be a positive integer"
    exit 1
fi

if [ -z "$CONF_PATH" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        CONF_PATH="/etc"
    else
        CONF_PATH="$HOME/.local/etc"
        mkdir -p "$CONF_PATH"
    fi
fi

mkdir -p /var/log/lego

LEGO=$(command -v lego || true)
if [ -z "$LEGO" ]; then
    log "ERROR: lego not installed"
    exit 1
fi

LEGO_VERSION=$($LEGO --version | awk '{print $3}')
if [ "$(printf '%s\n' 4.0.0 "$LEGO_VERSION" | sort -V | head -n1)" != "4.0.0" ]; then
    log "ERROR: lego >= 4.0.0 required"
    exit 1
fi

if [ ! -d "$CONF_PATH/lego" ] || [ -z "$(ls -A "$CONF_PATH/lego")" ]; then
    log "ERROR: $CONF_PATH/lego missing or empty"
    exit 1
fi

TEMP_DIR=$(mktemp -d /tmp/lego_cert.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT
cd "$TEMP_DIR" || exit 1

for config in "$CONF_PATH"/lego/*; do
    if ! safe_source "$config"; then
        log "Skipping $config"
        continue
    fi

    if ! check_var DOMAIN || ! check_var DNS_PROVIDER || ! check_var EMAIL; then
        log "Skipping invalid config $config"
        continue
    fi

    process_domain "$DOMAIN" LetsEncrypt "$CONF_PATH/letsencrypt/$DOMAIN" || true

    if [ -f /etc/zerossl/credentials ]; then
        ZEROSSL_API_KEY=$(sed -n '1p' /etc/zerossl/credentials)
        ZEROSSL_EAB_KID=$(sed -n '2p' /etc/zerossl/credentials)
        ZEROSSL_EAB_HMAC_KEY=$(sed -n '3p' /etc/zerossl/credentials)

        if [ -n "$ZEROSSL_API_KEY" ] && [ -n "$ZEROSSL_EAB_KID" ] && [ -n "$ZEROSSL_EAB_HMAC_KEY" ]; then
            export ZEROSSL_API_KEY ZEROSSL_EAB_KID ZEROSSL_EAB_HMAC_KEY
            process_domain "$DOMAIN" ZeroSSL "$CONF_PATH/zerossl/$DOMAIN" || true
        else
            log "ERROR: Incomplete ZeroSSL credentials"
        fi
    else
        log "ZeroSSL credentials not found, skipping"
    fi
done

if command -v nginx >/dev/null && command -v systemctl >/dev/null; then
    if nginx -t; then
        systemctl restart nginx
        log "Nginx restarted"
    else
        log "ERROR: nginx config test failed"
    fi
fi

log "Script completed successfully"
exit 0
