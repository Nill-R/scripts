#!/usr/bin/env bash

# Функция для проверки зависимостей
check_dependencies() {
    local telegram_send_path="$(which telegram-send)"

    if [ -z "$telegram_send_path" ]; then
        echo "ERROR: telegram-send is not installed."
        echo "FIX: Please install telegram-send."
        exit 1
    fi
}

# Функция для получения занятого пространства и использованных инодов
get_space_and_inodes() {
    local current_space
    local current_inodes
    local threshold=90

    current_space=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
    current_inodes=$(df -i / | grep / | awk '{ print $5}' | sed 's/%//g')

    if [ "$current_space" -gt "$threshold" ]; then
        send_notification "Free space at $(hostname) server is $current_space%"
    fi

    if [ "$current_inodes" -gt "$threshold" ]; then
        send_notification "Free inodes at $(hostname) server is $current_inodes%"
    fi
}

# Функция для отправки уведомления через Telegram
send_notification() {
    local message="$1"
    telegram-send "$message"
}

# Основная последовательность выполнения
main() {
    check_dependencies
    get_space_and_inodes
}

main "$@"