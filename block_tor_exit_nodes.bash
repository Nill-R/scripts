#!/usr/bin/env bash
# Block tor exit nodes with nftables
cd $(mktemp -d /tmp/script.XXXXXXX) || exit

NFT=$(which nft)
CURL=$(which curl)

if [ ! -f "$NFT" ]; then
        printf "ERROR: The nftables not installed.\n"
        printf "FIX: Please install nftables\n"
        printf "FIX: apt install nftables\n"
        rm -rf "$TEMP_DIR"
        exit 1
fi

if [ ! -f "$CURL" ]; then
        printf "ERROR: The curl not installed.\n"
        printf "FIX: Please install curl\n"
        printf "FIX: apt install curl\n"
        rm -rf "$TEMP_DIR"
        exit 1
fi

# add table filter
nft add table ip filter

# Add input chain to filter table
nft add chain ip filter input { type filter hook input priority 0 \; }

# Add named set
nft add set ip filter torexitnodes { type ipv4_addr \; flags dynamic, timeout \; timeout 5m \; }

# Download list of exit nodes and add to named set
curl -sSL "https://check.torproject.org/cgi-bin/TorBulkExitList.py?exit" | sed '/^#/d' | while read IP; do
  nft add element ip filter torexitnodes { $IP }
done

# Block ip addresses in the named set
nft add rule ip filter input ip saddr @torexitnodes drop

cd ~ || exit
rm -rf "$TEMP_DIR"
exit 0
