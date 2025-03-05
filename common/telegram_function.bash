#!/usr/bin/env bash

# Функция для отправки сообщений в Telegram
send_telegram_message() {
    # Проверяем, что передано сообщение
    if [ -z "$1" ]; then
        echo "Ошибка: Сообщение не указано"
        return 1
    fi

    # Путь к файлу конфигурации
    CONFIG_FILE="/path/to/telegram_config.conf"

    # Проверяем существование файла конфигурации
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Ошибка: Файл конфигурации не найден"
        return 1
    fi

    # Загружаем данные из файла конфигурации
    source "$CONFIG_FILE"

    # Проверяем, что необходимые переменные установлены
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "Ошибка: Отсутствуют необходимые данные в файле конфигурации"
        return 1
    fi

    # Формируем URL для отправки сообщения
    URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

    # Отправляем сообщение
    curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$1" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Сообщение успешно отправлено"
    else
        echo "Ошибка при отправке сообщения"
        return 1
    fi
}

# Пример использования функции
# send_telegram_message "Привет, это тестовое сообщение!"
