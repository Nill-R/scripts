#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

CONFIG_DIR="/etc/nginx/sites-available"

find "$CONFIG_DIR" -type f -name "*.conf" | while read -r file; do
    if grep -qE '^\s*listen.*443.*ssl.*http2.*$' "$file"; then
        echo "Обрабатывается файл: $file"
        
        sed -i -E 's/(^\s*listen.*443.*ssl.*)http2(.*$)/\1\2/' "$file"
        sed -i -E 's/(^\s*listen.*\[::\]:443.*ssl.*)http2(.*$)/\1\2/' "$file"
        
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
