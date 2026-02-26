#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

send_telegram_message() {
    if [ -z "$1" ]; then
        echo "Ошибка: Сообщение не указано"
        return 1
    fi

    CONFIG_FILE="/etc/telegram_notify.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Ошибка: Файл конфигурации не найден"
        return 1
    fi

    source "$CONFIG_FILE"

    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "Ошибка: Отсутствуют необходимые данные в файле конфигурации"
        return 1
    fi

    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

    curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$1" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Сообщение успешно отправлено"
    else
        echo "Ошибка при отправке сообщения"
        return 1
    fi
}
