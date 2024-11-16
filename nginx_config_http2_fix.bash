#!/usr/bin/env bash

# Директория с конфигами Nginx
CONFIG_DIR="/etc/nginx/sites=available"

# Проходим рекурсивно по директории
find "$CONFIG_DIR" -type f -name "*.conf" | while read -r file; do
    # Проверяем наличие старого формата строк
    if grep -qE '^\s*listen.*443.*ssl.*http2.*$' "$file"; then
        echo "Обрабатывается файл: $file"
        
        # Удаляем `http2` из строк listen
        sed -i -E 's/(^\s*listen.*443.*ssl.*)http2(.*$)/\1\2/' "$file"
        sed -i -E 's/(^\s*listen.*\[::\]:443.*ssl.*)http2(.*$)/\1\2/' "$file"
        
        # Добавляем `http2 on;` после второй директивы listen
        awk '
            /listen.*443.*ssl/ { 
                print $0; 
                count++;
                if (count == 2) print "    http2 on;";
                next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        echo "Файл уже в корректном формате: $file"
    fi
done
