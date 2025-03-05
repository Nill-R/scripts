#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# Block Tor exit nodes with nftables

# Функция для проверки наличия необходимых программ
check_dependencies() {
    local nft_path="$(which nft)"
    local curl_path="$(which curl)"

    if [ -z "$nft_path" ]; then
        echo "ERROR: nftables is not installed."
        echo "FIX: Please install nftables with 'apt install nftables'"
        exit 1
    fi

    if [ -z "$curl_path" ]; then
        echo "ERROR: curl is not installed."
        echo "FIX: Please install curl with 'apt install curl'"
        exit 1
    fi
}

# Функция для настройки nftables
setup_nftables() {
    nft add table ip filter
    nft add chain ip filter input '{ type filter hook input priority 0; }'
    nft add set ip filter torexitnodes '{ type ipv4_addr; flags dynamic, timeout; timeout 5m; }'
}

# Функция для добавления Tor выходных узлов в набор
add_tor_exit_nodes() {
    curl -sSL "https://check.torproject.org/cgi-bin/TorBulkExitList.py?exit" | sed '/^#/d' | while read -r ip; do
        nft add element ip filter torexitnodes "{ $ip }"
    done
}

# Функция для блокировки трафика через Tor выходные узлы
block_tor_exit_nodes() {
    nft add rule ip filter input ip saddr @torexitnodes drop
}

# Функция для очистки
cleanup() {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/script.XXXXXXX)
    cd "$temp_dir" || exit 1
    # Здесь можно добавить код для удаления правил и набора nftables
    cd ~ || exit 1
    rm -rf "$temp_dir"
}

# Основная последовательность выполнения
main() {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/script.XXXXXXX)
    cd "$temp_dir" || exit 1

    check_dependencies
    setup_nftables
    add_tor_exit_nodes
    block_tor_exit_nodes

    cd ~ || exit 1
    rm -rf "$temp_dir"
}

main "$@"