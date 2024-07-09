#!/usr/bin/env bash

# Путь к файлу с функцией отправки сообщений в Telegram
TELEGRAM_FUNCTIONS="/usr/local/bin/telegram_functions.bash"

# Проверка наличия файла с функцией отправки сообщений
if [ ! -f "$TELEGRAM_FUNCTIONS" ]; then
    echo "ERROR: Telegram functions file not found at $TELEGRAM_FUNCTIONS"
    exit 1
fi

# Загрузка функции отправки сообщений
source "$TELEGRAM_FUNCTIONS"

# Функция для получения занятого пространства и использованных инодов
get_space_and_inodes() {
    local current_space
    local current_inodes
    local threshold=90

    current_space=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
    current_inodes=$(df -i / | grep / | awk '{ print $5}' | sed 's/%//g')

    if [ "$current_space" -gt "$threshold" ]; then
        send_telegram_message "Free space at $(hostname) server is $current_space%"
    fi

    if [ "$current_inodes" -gt "$threshold" ]; then
        send_telegram_message "Free inodes at $(hostname) server is $current_inodes%"
    fi
}

# Основная последовательность выполнения
main() {
    get_space_and_inodes
}

main "$@"
