#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# version 2.0.2
# © Sergey Voronov 2010
# © Nill Ringil 2010-2025
# © LLM Claude 3.5 Sonnet 2024

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

find /etc/php -type f -path "*/fpm/pool.d/*" -exec grep -l "php_admin_value\[error_log\]" {} \; | while read -r pool_file; do
    error_log=$(grep "php_admin_value\[error_log\]" "$pool_file" | grep -v ";" | awk '{print $3}')
    [ -z "$error_log" ] && continue
    
    for log in $error_log; do
        NAME=$(basename "$log")
        FLAG="$STATE_DIR/${NAME}.cnt"
        
        [ ! -e "$log" ] && continue
        
        CURR_N=$(wc -l "$log" | awk '{ print $1 }')
        if [ ! -e "$FLAG" ]; then
            echo "$CURR_N" > "$FLAG"
            chmod 644 "$FLAG"
            continue
        fi
        
        LAST_N=$(cat "$FLAG")
        # Ensure LAST_N contains a number
        [[ ! "$LAST_N" =~ ^[0-9]+$ ]] && LAST_N=0
        
        if [ "$CURR_N" -gt "$LAST_N" ]; then
            PHP_VERSION=$(dirname "$pool_file" | grep -oP '/php/\K[0-9]+\.[0-9]+')
            POOL_NAME=$(basename "$pool_file" .conf)
            STR=$((CURR_N - LAST_N))
            
            MESSAGE="<b>PHP-FPM Error Alert</b>
Version: PHP ${PHP_VERSION}
Pool: ${POOL_NAME}
Log: ${log}
New lines: ${LAST_N} → ${CURR_N}

<pre>$(tail -n $STR "$log")</pre>"
            
            send_telegram_message "$MESSAGE"
        fi
        
        echo "$CURR_N" > "$FLAG"
    done
done

exit 0