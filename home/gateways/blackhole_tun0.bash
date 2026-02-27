#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# File with subnets (specify the path to your file)
SUBNET_FILE="/etc/wireguard/local_networks.txt"

# Function to add a route to blackhole
add_blackhole_route() {
    local subnet="$1"
    # Проверяем, есть ли уже маршрут, чтобы не добавлять дубликаты
    if ! ip route show | grep -q "^blackhole $subnet"; then
        ip route replace blackhole "$subnet"
        echo "Added blackhole route for subnet: $subnet"
    fi
}

# Check if tun0 interface exists
if ip link show tun0 &>/dev/null; then
    echo "Interface tun0 is active. Exiting."
    exit 0
fi

# If tun0 is not found, add routes for subnets from the file
if [[ -f "$SUBNET_FILE" ]]; then
    while IFS= read -r subnet; do
        # Skip empty lines and comment lines (beginning with #)
        [[ -z "$subnet" || "$subnet" =~ ^# ]] && continue
        add_blackhole_route "$subnet"
    done < "$SUBNET_FILE"
else
    echo "File with subnets not found: $SUBNET_FILE" >&2
    exit 1
fi

exit 0
