#!/usr/bin/env bash

# URL для загрузки списка подсетей
SUBNET_URL="https://antifilter.download/list/allyouneed.lst"

# Путь к файлу с подсетями
SUBNET_FILE="subnets.txt"

# Интерфейс, через который делаем роутинг
INTERFACE="wg0"

# Скачиваем файл с подсетями
curl -o "$SUBNET_FILE" "$SUBNET_URL"

# Создаем временный файл для хранения подсетей в формате ipset
TMP_SET_FILE=$(mktemp)
trap 'rm -f "$TMP_SET_FILE"' EXIT

# Сбрасываем набор перед обновлением
nft flush set inet filter subnets

# Создаем пустой набор в nftables для хранения подсетей
nft add table inet filter
nft add set inet filter subnets { type ipv4_addr\; flags interval\; }

# Читаем файл с подсетями и добавляем их в набор в nftables
subnets_string=""
while IFS= read -r subnet; do
    subnets_string="$subnets_string $subnet"
done < "$SUBNET_FILE"

# Добавляем все подсети в набор в nftables
nft add element inet filter subnets { $subnets_string }

# Добавляем правила маршрутизации для подсетей через интерфейс wg0
nft add rule inet filter output ip saddr @subnets counter accept
ip -4 route flush table 100
ip -4 route add table 100 unreachable default metric 4278198272
nft add rule inet filter output ip saddr @subnets counter accept
nft add rule inet filter output ip saddr @subnets counter accept

# Применяем изменения
nft --debug=netlink list ruleset
ip -4 route show table 100
