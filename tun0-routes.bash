#!/usr/bin/env bash

# Пути к файлам со списком подсетей (по одной на строку)
LOCAL_NETWORKS_FILE="/etc/antirkn/local_networks.txt"
REMOTE_NETWORKS_FILE="/etc/antirkn/remote_networks.txt"
GOOGLE_NETWORKS_FILE="/etc/antirkn/google.txt"
AKAMAI_NETWORKS_FILE="/etc/antirkn/akamai.txt"
EXCLUDE_NETWORKS_FILE="/etc/antirkn/exclude_networks.txt"
WG_INTERFACE="tun0"

# Функция для настройки маршрутов
setup_routes() {
    local file="$1"
    
    while IFS= read -r network; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$network" || "$network" =~ ^[[:space:]]*# ]] && continue
        
        # Проверяем, не находится ли сеть в списке исключений
        if [ -f "$EXCLUDE_NETWORKS_FILE" ]; then
            if grep -q "^${network}$" "$EXCLUDE_NETWORKS_FILE"; then
                # Если сеть в списке исключений, удаляем маршрут если он существует
                if ip route show | grep -q "^${network} dev ${WG_INTERFACE}"; then
                    ip route del "$network" dev "$WG_INTERFACE"
                fi
                continue
            fi
        fi
        
        # Добавляем маршрут
        ip route replace "$network" dev "$WG_INTERFACE"
    done < "$file"
}

# Основная логика
main() {
    # Проверяем существование файлов с сетями
    if [ ! -f "$LOCAL_NETWORKS_FILE" ]; then
        echo "Error: Local networks file not found at $LOCAL_NETWORKS_FILE"
    fi
    if [ ! -f "$REMOTE_NETWORKS_FILE" ]; then
        echo "Error: Remote networks file not found at $REMOTE_NETWORKS_FILE"
    fi
    if [ ! -f "$GOOGLE_NETWORKS_FILE" ]; then
        echo "Error: Google networks file not found at $GOOGLE_NETWORKS_FILE"
    fi
    if [ ! -f "$AKAMAI_NETWORKS_FILE" ]; then
        echo "Error: Akamai networks file not found at $AKAMAI_NETWORKS_FILE"
    fi

    # Настраиваем маршруты
    setup_routes "$LOCAL_NETWORKS_FILE"
    setup_routes "$REMOTE_NETWORKS_FILE"
    setup_routes "$GOOGLE_NETWORKS_FILE"
    setup_routes "$AKAMAI_NETWORKS_FILE"

    # Дополнительно проверяем и удаляем маршруты для сетей из списка исключений
    if [ -f "$EXCLUDE_NETWORKS_FILE" ]; then
        while IFS= read -r network; do
            # Пропускаем пустые строки и комментарии
            [[ -z "$network" || "$network" =~ ^[[:space:]]*# ]] && continue
            
            # Удаляем маршрут если он существует
            if ip route show | grep -q "^${network} dev ${WG_INTERFACE}"; then
                ip route del "$network" dev "$WG_INTERFACE"
            fi
        done < "$EXCLUDE_NETWORKS_FILE"
    fi
}

# Запуск скрипта с выводом в лог
main 2>&1 | logger -t wg-routes