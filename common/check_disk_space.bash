#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

TELEGRAM_FUNCTIONS="/usr/local/bin/telegram_function.bash"

if [ ! -f "$TELEGRAM_FUNCTIONS" ]; then
    echo "ERROR: Telegram functions file not found at $TELEGRAM_FUNCTIONS"
    exit 1
fi

source "$TELEGRAM_FUNCTIONS"

get_space_and_inodes() {
    local current_space
    local current_inodes
    local threshold=95

    current_space=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
    current_inodes=$(df -i / | grep / | awk '{ print $5}' | sed 's/%//g')

    if [ "$current_space" -gt "$threshold" ]; then
        send_telegram_message "Free space at $(hostname) server is $current_space%"
    fi

    if [ "$current_inodes" -gt "$threshold" ]; then
        send_telegram_message "Free inodes at $(hostname) server is $current_inodes%"
    fi
}

main() {
    get_space_and_inodes
}

main "$@"

exit 0
