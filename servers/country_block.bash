#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# ##############################################################################
# Description:  Uses nftables to block specified countries from accessing the server for specified ports and protocols
# Syntax:       countries_block.bash [-pt tcp_ports] [-pu udp_ports] [-pi icmp_block] countrycode [countrycode] ......
#               Use the standard locale country codes to get the proper IP list. eg.
#               countries_block.bash -pt 80,443 -pu 53 -pi true cn ru ro
#               Will create tables that block all requests from China, Russia and Romania for specified ports and protocols
# Note:         To get a sorted list of IP sets for a specific country, you can list the set like:
#               nft list set inet filter cn
# ##############################################################################
# Defining some defaults
nft="/usr/sbin/nft"
sourceURL="http://www.ipdeny.com/ipblocks/data/countries/"
cache_dir="/var/cache/country_block"

# Default values for protocol flags
tcp_ports="all"
udp_ports="all"
icmp_block="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        -pt)
            tcp_ports="$2"
            shift # past argument
            shift # past value
            ;;
        -pu)
            udp_ports="$2"
            shift # past argument
            shift # past value
            ;;
        -pi)
            icmp_block="$2"
            shift # past argument
            shift # past value
            ;;
        *)
            countries+=("$1")
            shift # past argument
            ;;
    esac
done

# Verifying that the program 'nft' is installed
if ! command -v "$nft" &>/dev/null; then
    echo "nftables is not installed. Exiting."
    exit 1
fi

# Creating the cache directory if it doesn't exist
mkdir -p "$cache_dir"

# Creating the nftables table and chain if they don't exist
if ! $nft list table inet filter &>/dev/null; then
    $nft add table inet filter
    $nft add chain inet filter input { type filter hook input priority 0 \; }
else
    # Flush the existing rules and delete sets for cleaning up old countries
    echo "Flushing existing rules and deleting old sets..."
    $nft flush chain inet filter input
    for set in $($nft list sets | grep 'set inet filter' | awk '{print $4}'); do
        $nft delete set inet filter "$set"
    done
fi

# Download and apply country IP sets
for countrycode in "${countries[@]}"; do
    echo "Processing country code: $countrycode"
    iplist="${cache_dir}/${countrycode}.zone"

    # Fetching the IP list if not cached or different from remote
    wget -q -O - "${sourceURL}${countrycode}.zone" | tee >(md5sum > "${iplist}.md5.new") | cmp -s "${iplist}" -
    if [ $? -ne 0 ]; then
        echo "Downloading new IP list for ${countrycode}."
        wget -q -O "$iplist" "${sourceURL}${countrycode}.zone"
        mv "${iplist}.md5.new" "${iplist}.md5"
    else
        echo "Using cached IP list for ${countrycode}."
        rm "${iplist}.md5.new"
    fi

    # Create or flush the nftables set for the country
    $nft add set inet filter "${countrycode}" { type ipv4_addr\; flags interval\; auto-merge\;} 2>/dev/null
    $nft flush set inet filter "${countrycode}"

    echo "Adding IPs to the set for ${countrycode} (this may take a while)..."
    # Adding IPs to the set
    while read -r ip; do
        $nft add element inet filter "${countrycode}" { "$ip" }
    done < "$iplist"

    # Adding drop rules for the country set
    if [ "$tcp_ports" != "none" ]; then
        if [ "$tcp_ports" == "all" ]; then
            $nft add rule inet filter input ip saddr @"${countrycode}" tcp drop
        else
            IFS=',' read -ra ports <<< "$tcp_ports"
            for port in "${ports[@]}"; do
                $nft add rule inet filter input ip saddr @"${countrycode}" tcp dport "$port" drop
            done
        fi
    fi

    if [ "$udp_ports" != "none" ]; then
        if [ "$udp_ports" == "all" ]; then
            $nft add rule inet filter input ip saddr @"${countrycode}" udp drop
        else
            IFS=',' read -ra ports <<< "$udp_ports"
            for port in "${ports[@]}"; do
                $nft add rule inet filter input ip saddr @"${countrycode}" udp dport "$port" drop
            done
        fi
    fi

    if [ "$icmp_block" == "true" ]; then
        $nft add rule inet filter input ip saddr @"${countrycode}" icmp type echo-request drop
    fi
done

echo "Done."

exit 0
