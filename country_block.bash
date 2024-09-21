
#!/usr/bin/env bash

# ##############################################################################
# Description:  Uses nftables to block full countries from accessing the server for all ports and protocols
# Syntax:       countries_block_nft.bash countrycode [countrycode] ......
#               Use the standard locale country codes to get the proper IP list. eg.
#               countries_block.bash cn ru ro
#               Will create tables that block all requests from China, Russia and Romania
# Note:         To get a sorted list of IP sets for a specific country, you can list the set like:
#               nft list set inet filter cn
# ##############################################################################
# Defining some defaults
nft="/usr/sbin/nft"
sourceURL="http://www.ipdeny.com/ipblocks/data/countries/"

# Verifying that the program 'nft' is installed
if ! command -v $nft &>/dev/null; then
    echo "nftables is not installed. Exiting."
    exit 1
fi

# Creating a temporary directory
tempdir=$(mktemp -d)

# Ensure the temporary directory is created
if [ ! -d "$tempdir" ]; then
    echo "Failed to create temporary directory. Exiting."
    exit 1
fi

# Creating the nftables table and chain if they don't exist
$nft list table inet filter &>/dev/null
if [ $? -ne 0 ]; then
    $nft add table inet filter
    $nft add chain inet filter input { type filter hook input priority 0 \; }
fi

# Download and apply country IP sets
for countrycode in "$@"; do
    echo "Processing country code: $countrycode"
    iplist="${tempdir}/${countrycode}.zone"

    # Fetching the IP list
    wget -q -O $iplist "${sourceURL}${countrycode}.zone"
    if [ $? -ne 0 ]; then
        echo "Failed to download IP list for ${countrycode}. Skipping."
        continue
    fi

    # Create or flush the nftables set for the country
    $nft list set inet filter ${countrycode} &>/dev/null
    if [ $? -ne 0 ]; then
        $nft add set inet filter ${countrycode} { type ipv4_addr\; flags interval\; }
    else
        $nft flush set inet filter ${countrycode}
    fi

    # Adding IPs to the set
    while read -r ip; do
        $nft add element inet filter ${countrycode} { $ip }
    done < $iplist

    # Adding drop rule for the country set
    $nft list ruleset | grep -q "ip saddr @${countrycode} drop"
    if [ $? -ne 0 ]; then
        $nft add rule inet filter input ip saddr @${countrycode} drop
    fi
done

# Clean up the temporary directory
rm -rf "$tempdir"
echo "Done."
