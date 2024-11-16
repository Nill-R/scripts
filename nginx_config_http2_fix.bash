#!/usr/bin/env bash

# Директория с конфигами Nginx
CONFIG_DIR="/etc/nginx/sites-available"

# Проходим рекурсивно по директории
find "$CONFIG_DIR" -type f -name "*.conf" | while read -r file; do
    # Проверяем наличие старого формата строк
    if grep -qE '^\s*listen.*443.*ssl.*http2.*$' "$file"; then
        echo "Обрабатывается файл: $file"
        
        # Удаляем `http2` из строки `listen`
        sed -i -E 's/(^\s*listen.*443.*ssl.*)http2(.*$)/\1\2/' "$file"
        sed -i -E 's/(^\s*listen.*\[::\]:443.*ssl.*)http2(.*$)/\1\2/' "$file"
        
        # Добавляем строку `http2 on;` после модифицированных строк, если её нет
        if ! grep -qE '^\s*http2 on;$' "$file"; then
            sed -i -E '/^\s*listen.*443.*ssl.*/a \    http2 on;' "$file"
        fi
    else
        echo "Файл уже в корректном формате: $file"
    fi
done
