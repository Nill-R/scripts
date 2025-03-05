#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

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
    
    [[ ! -s "$file" ]] && echo "Warning: $file is empty" | logger -t tun0-routes && return
    
    while IFS= read -r network; do
        [[ -z "$network" || "$network" =~ ^[[:space:]]*# ]] && continue
        
        if [ -f "$EXCLUDE_NETWORKS_FILE" ]; then
            if grep -q "^${network}$" "$EXCLUDE_NETWORKS_FILE"; then
                if ip route show | grep -q "^${network} dev ${TUN_INTERFACE}"; then
                    ip route del "$network" dev "$TUN_INTERFACE"
                fi
                continue
            fi
        fi
        
        ip route replace "$network" dev "$TUN_INTERFACE"
    done < "$file"
}

# Функция для принудительной маршрутизации адресов через default gw
setup_include_addresses() {
    if [ ! -s "$INCLUDE_ADDRESSES_FILE" ]; then
        echo "Warning: $INCLUDE_ADDRESSES_FILE is empty" | logger -t tun0-routes
        return
    fi
    while IFS= read -r address; do
        [[ -z "$address" || "$address" =~ ^[[:space:]]*# ]] && continue
        ip route replace "$address" via "$DEFAULT_GW"
    done < "$INCLUDE_ADDRESSES_FILE"
}

# Функция для резолвинга доменных имен и их маршрутизации через default gw
setup_include_domains() {
    if [ ! -s "$INCLUDE_DOMAINS_FILE" ]; then
        echo "Warning: $INCLUDE_DOMAINS_FILE is empty" | logger -t tun0-routes
        return
    fi
    while IFS= read -r domain; do
        [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]] && continue
        
        resolved_ips=$(dig +short "$domain" | grep -E "^[0-9.]+$")
        if [[ -z "$resolved_ips" ]]; then
            echo "Warning: $domain could not be resolved" | logger -t tun0-routes
            continue
        fi
        
        for ip in $resolved_ips; do
            ip route replace "$ip" via "$DEFAULT_GW"
        done
    done < "$INCLUDE_DOMAINS_FILE"
}

# Основная логика
main() {
    for file in "$LOCAL_NETWORKS_FILE" "$REMOTE_NETWORKS_FILE" "$GOOGLE_NETWORKS_FILE" "$AKAMAI_NETWORKS_FILE"; do
        if [ ! -f "$file" ]; then
            echo "Error: Networks file not found at $file" | logger -t tun0-routes
        else
            setup_routes "$file"
        fi
    done
    
    setup_include_addresses
    setup_include_domains
}

# Запуск скрипта с выводом в лог
main 2>&1 | logger -t tun0-routes

exit 0
