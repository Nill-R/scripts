#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 <domain_list_file>"
    exit 1
fi

DOMAINS_FILE="$1"
LOG_DIR="/var/log/domains"
LOG_FILE="$LOG_DIR/$(basename "$DOMAINS_FILE" .lst).log"

# Создаем каталог для логов, если он не существует
mkdir -p "$LOG_DIR"

echo "[$(date)] Starting domain expiration check for $DOMAINS_FILE" >> "$LOG_FILE"

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "[$(date)] Domain list file not found!" >> "$LOG_FILE"
    exit 1
fi

while IFS= read -r domain; do
    if [ -n "$domain" ]; then
        /usr/local/bin/check_domain_expiration.bash -w 30 -c 10 -d "$domain" >/tmp/$domain.exp.check 2>&1
        if [ $? -ne 0 ]; then
            apprise -e -t "Domain $domain is expired" -b "$(cat /tmp/$domain.exp.check)\nCheck from $(hostname) at $(date)"
            echo "[$(date)] Domain $domain check failed" >> "$LOG_FILE"
        else
            echo "[$(date)] Domain $domain is OK" >> "$LOG_FILE"
        fi
    fi
done < "$DOMAINS_FILE"

echo "[$(date)] Domain expiration check completed for $DOMAINS_FILE" >> "$LOG_FILE"
