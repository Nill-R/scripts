#!/usr/bin/env bash

# Пути к файлам со списками сетей, адресов и доменов (по одной записи на строку)
LOCAL_NETWORKS_FILE="/etc/antirkn/local_networks.txt"
REMOTE_NETWORKS_FILE="/etc/antirkn/remote_networks.txt"
GOOGLE_NETWORKS_FILE="/etc/antirkn/google.txt"
AKAMAI_NETWORKS_FILE="/etc/antirkn/akamai.txt"
EXCLUDE_NETWORKS_FILE="/etc/antirkn/exclude_networks.txt"
INCLUDE_ADDRESSES_FILE="/etc/antirkn/include_addresses.txt"
INCLUDE_DOMAINS_FILE="/etc/antirkn/include_domains.txt"
TUN_INTERFACE="tun0"

# Определяем default gw
DEFAULT_GW=$(ip route show default | awk '/default/ {print $3}')

# Функция для настройки маршрутов через tun0
setup_routes() {
    local file="$1"
    
    while IFS= read -r network; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$network" || "$network" =~ ^[[:space:]]*# ]] && continue
        
        # Проверяем, не находится ли сеть в списке исключений
        if [ -f "$EXCLUDE_NETWORKS_FILE" ]; then
            if grep -q "^${network}$" "$EXCLUDE_NETWORKS_FILE"; then
                # Если сеть в списке исключений, удаляем маршрут если он существует
                if ip route show | grep -q "^${network} dev ${TUN_INTERFACE}"; then
                    ip route del "$network" dev "$TUN_INTERFACE"
                fi
                continue
            fi
        fi
        
        # Добавляем маршрут через tun0
        ip route replace "$network" dev "$TUN_INTERFACE"
    done < "$file"
}

# Функция для принудительной маршрутизации адресов через default gw
setup_include_addresses() {
    if [ ! -f "$INCLUDE_ADDRESSES_FILE" ]; then
        return
    fi
    while IFS= read -r address; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$address" || "$address" =~ ^[[:space:]]*# ]] && continue
        
        # Добавляем маршрут через default gw
        ip route replace "$address" via "$DEFAULT_GW"
    done < "$INCLUDE_ADDRESSES_FILE"
}

# Функция для резолвинга доменных имен и их маршрутизации через default gw
setup_include_domains() {
    if [ ! -f "$INCLUDE_DOMAINS_FILE" ]; then
        return
    fi
    while IFS= read -r domain; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]] && continue
        
        # Получаем IP-адреса домена
        for ip in $(dig +short "$domain" | grep -E "^[0-9.]+$"); do
            ip route replace "$ip" via "$DEFAULT_GW"
        done
    done < "$INCLUDE_DOMAINS_FILE"
}

# Основная логика
main() {
    # Проверяем существование файлов с сетями
    for file in "$LOCAL_NETWORKS_FILE" "$REMOTE_NETWORKS_FILE" "$GOOGLE_NETWORKS_FILE" "$AKAMAI_NETWORKS_FILE"; do
        if [ ! -f "$file" ]; then
            echo "Error: Networks file not found at $file"
        else
            setup_routes "$file"
        fi
    done
    
    # Настраиваем маршруты для отдельных IP-адресов
    setup_include_addresses
    
    # Настраиваем маршруты для доменных имен
    setup_include_domains
}

# Запуск скрипта с выводом в лог
main 2>&1 | logger -t tun0-routes

exit 0
