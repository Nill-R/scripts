#!/usr/bin/env bash

set -eo pipefail

# Function to display the usage of the script
display_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  -c, --config PATH   Specify custom config path"
    echo "  -h, --help          Display this help message"
}

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a variable is set
check_var() {
    if [ -z "${!1}" ]; then
        log "ERROR: $1 is not set in the configuration file"
        exit 1
    fi
}

# Function to safely source a file, converting CRLF to LF if necessary
safe_source() {
    local file="$1"
    if [ -f "$file" ]; then
        # Check if file contains CRLF
        if grep -q $'\r' "$file"; then
            log "WARNING: $file contains CRLF line endings. Converting to LF."
            # Create a temporary file with LF line endings
            local tmp_file=$(mktemp)
            tr -d '\r' < "$file" > "$tmp_file"
            source "$tmp_file"
            rm "$tmp_file"
        else
            source "$file"
        fi
    else
        log "ERROR: Configuration file $file not found"
        exit 1
    fi
}

# Parse command line arguments
CONF_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONF_PATH="$2"
            shift 2
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            exit 1
            ;;
    esac
done

# Set default config path if not specified
if [ -z "$CONF_PATH" ]; then
    if [ "$(id -u)" = 0 ]; then
        CONF_PATH="/etc"
    else
        CONF_PATH="$HOME/.local/etc"
        mkdir -p "$CONF_PATH"
    fi
fi

# Check for lego installation
LEGO=$(which lego)
if [ ! -f "$LEGO" ]; then
    log "ERROR: lego is not installed."
    log "Please install lego: https://github.com/go-acme/lego"
    exit 1
fi

# Check lego version (assuming 4.0.0 is minimum)
LEGO_VERSION=$($LEGO --version | awk '{print $3}')
if [ "$(printf '%s\n' "4.0.0" "$LEGO_VERSION" | sort -V | head -n1)" != "4.0.0" ]; then
    log "ERROR: lego version must be at least 4.0.0"
    exit 1
fi

# Check for lego config directory
if [ ! -d "$CONF_PATH/lego" ] || [ -z "$(ls -A "$CONF_PATH/lego/")" ]; then
    log "ERROR: $CONF_PATH/lego does not exist or is empty"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d /tmp/lego_cert.XXXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT
cd "$TEMP_DIR" || exit

# Process each domain configuration
for config in "$CONF_PATH"/lego/*; do
    # Use safe_source function instead of direct source
    safe_source "$config"

    # Check required variables
    check_var "DOMAIN"
    check_var "DNS_PROVIDER"
    check_var "EMAIL"

    ACTION="run"
    if [ -d "$CONF_PATH/letsencrypt/$DOMAIN" ]; then
        ACTION="renew"
        # Backup existing certificates
        cp -r "$CONF_PATH/letsencrypt/$DOMAIN" "$CONF_PATH/letsencrypt/$DOMAIN.bak"
    fi

    log "Processing domain: $DOMAIN"
    export LEGO_DISABLE_CNAME_SUPPORT=true

    if ! $LEGO --dns "$DNS_PROVIDER" \
            --domains "*.$DOMAIN" \
            --domains "$DOMAIN" \
            --email "$EMAIL" \
            --path="$CONF_PATH/letsencrypt/$DOMAIN" \
            --accept-tos "$ACTION"; then
        log "ERROR: Failed to $ACTION certificate for $DOMAIN"
        continue
    fi

    log "Successfully processed $DOMAIN"
done

# Optionally restart Nginx
if [ -x "$(command -v nginx)" ] && [ -x "$(command -v systemctl)" ]; then
    if nginx -t; then
        systemctl restart nginx
        log "Nginx restarted successfully"
    else
        log "ERROR: Nginx configuration test failed, not restarting"
    fi
else
    log "Nginx or systemctl not found, skipping Nginx restart"
fi

log "Script completed successfully"
exit 0