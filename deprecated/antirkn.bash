#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# URL for downloading the subnets list
SUBNET_URL="https://antifilter.download/list/allyouneed.lst"

# Path to the subnets file
SUBNET_FILE="subnets.txt"

# Interface for routing
INTERFACE="wg0"

# Download the subnets file
curl -o "$SUBNET_FILE" "$SUBNET_URL"

# Create a temporary file to store subnets in ipset format
TMP_SET_FILE=$(mktemp)
trap 'rm -f "$TMP_SET_FILE"' EXIT

# Flush the set before updating
nft flush set inet filter subnets

# Create an empty set in nftables to store subnets
nft add table inet filter
nft add set inet filter subnets { type ipv4_addr\; flags interval\; }

# Read the subnets file and add them to the nftables set
subnets_string=""
while IFS= read -r subnet; do
    subnets_string="$subnets_string $subnet"
done < "$SUBNET_FILE"

# Add all subnets to the nftables set
nft add element inet filter subnets { "$subnets_string" }

# Add routing rules for subnets via the wg0 interface
nft add rule inet filter output ip saddr @subnets counter accept
ip -4 route flush table 100
ip -4 route add table 100 unreachable default metric 4278198272

# Apply the changes
nft --debug=netlink list ruleset
ip -4 route show table 100
