#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

send_telegram_message() {
    if [ -z "$1" ]; then
        echo "Error: Message not specified"
        return 1
    fi

    CONFIG_FILE="/etc/telegram_notify.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        return 1
    fi

    source "$CONFIG_FILE"

    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "Error: Missing required data in configuration file"
        return 1
    fi

    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

    curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$1" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Message sent successfully"
    else
        echo "Error sending message"
        return 1
    fi
}
