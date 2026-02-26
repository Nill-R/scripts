#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Файл с подсетями (укажите путь к вашему файлу)
SUBNET_FILE="/etc/wireguard/local_networks.txt"

# Функция для добавления маршрута в blackhole
add_blackhole_route() {
    local subnet="$1"
    # Проверяем, есть ли уже маршрут, чтобы не добавлять дубликаты
    if ! ip route show | grep -q "^blackhole $subnet"; then
        ip route replace blackhole "$subnet"
        echo "Добавлен маршрут в blackhole для подсети: $subnet"
    fi
}

# Проверяем наличие интерфейса tun0
if ip link show tun0 &>/dev/null; then
    echo "Интерфейс tun0 активен. Завершаю работу."
    exit 0
fi

# Если tun0 не найден, добавляем маршруты для подсетей из файла
if [[ -f "$SUBNET_FILE" ]]; then
    while IFS= read -r subnet; do
        # Пропускаем пустые строки и строки с комментарием (начинаются с #)
        [[ -z "$subnet" || "$subnet" =~ ^# ]] && continue
        add_blackhole_route "$subnet"
    done < "$SUBNET_FILE"
else
    echo "Файл с подсетями не найден: $SUBNET_FILE" >&2
    exit 1
fi

exit 0
