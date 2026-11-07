#!/usr/bin/env bash

set -euo pipefail

# Download and load nftables sets
echo "Updating AS Network Blocklists..."
    wget https://raw.githubusercontent.com/C24Be/AS_Network_List/main/blacklists_nftables/blacklist.nft
    wget https://raw.githubusercontent.com/C24Be/AS_Network_List/main/blacklists_nftables/blacklist-v4.nft
    wget https://raw.githubusercontent.com/C24Be/AS_Network_List/main/blacklists_nftables/blacklist-v6.nft
    sudo nft -f blacklist.nft
    sudo nft -f blacklist-v4.nft
    sudo nft -f blacklist-v6.nft

# Protect VM from incoming blacklist sources
    sudo nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
    sudo nft add rule inet filter input ip saddr @blacklist_v4 counter reject
    sudo nft add rule inet filter input ip6 saddr @blacklist_v6 counter reject