#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# version 3.0.0
# © Sergey Voronov 2010
# © Nill Ringil 2010-2026
# © LLM Claude 3.5 Sonnet 2024
# © LLM Claude 4.6 Sonnet 2026

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/opt/bin:/snap/bin

send_telegram_message() {
    [ -z "$1" ] && return 1
    CONFIG_FILE="/etc/telegram-notify.conf"
    [ ! -f "$CONFIG_FILE" ] && return 1
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && return 1
    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$1" -d parse_mode="HTML" > /dev/null
}

eerror() {
    echo "$*"
    exit 1
}

[ ! -d "/etc/php" ] && eerror "PHP installation not found"

STATE_DIR="/var/tmp/php-fpm-errors"
mkdir -p "$STATE_DIR"
chmod 755 "$STATE_DIR"

find /etc/php -type f -name "*.conf" -path "*/fpm/pool.d/*" | while read -r pool_file; do
    # Skip pool files without an error_log directive
    grep -q "php_admin_value\[error_log\]" "$pool_file" || continue

    PHP_VERSION=$(echo "$pool_file" | grep -oP '/php/\K[0-9]+\.[0-9]+')
    POOL_NAME=$(basename "$pool_file" .conf)

    [ -z "$PHP_VERSION" ] && continue

    # Extract all non-commented error_log values from the pool file
    while read -r error_log; do
        [ -z "$error_log" ] && continue
        [ ! -e "$error_log" ] && continue

        LOG_NAME=$(basename "$error_log")
        # State file is unique per PHP version + pool name + log basename
        FLAG="$STATE_DIR/php${PHP_VERSION}-${POOL_NAME}-${LOG_NAME}.cnt"

        CURR_N=$(wc -l < "$error_log")

        if [ ! -e "$FLAG" ]; then
            echo "$CURR_N" > "$FLAG"
            chmod 644 "$FLAG"
            continue
        fi

        LAST_N=$(cat "$FLAG")
        [[ ! "$LAST_N" =~ ^[0-9]+$ ]] && LAST_N=0

        if [ "$CURR_N" -gt "$LAST_N" ]; then
            STR=$((CURR_N - LAST_N))

            MESSAGE="<b>PHP-FPM Error Alert</b>
Version: PHP ${PHP_VERSION}
Pool: ${POOL_NAME}
Log: ${error_log}
New lines: ${LAST_N} → ${CURR_N}

<pre>$(tail -n "$STR" "$error_log")</pre>"

            send_telegram_message "$MESSAGE"
        fi

        echo "$CURR_N" > "$FLAG"

    done < <(grep "php_admin_value\[error_log\]" "$pool_file" | grep -v "^\s*;" | awk '{print $3}')
done

exit 0
