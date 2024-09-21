#!/usr/bin/env bash

# ##############################################################################
# Description:  Uses IPSET and IPTABLES to block full countries from accessing the server for all ports and protocols
# Syntax:       countries_block.bash countrycode [countrycode] ......
#               Use the standard locale country codes to get the proper IP list. eg.
#               countries_block.bash cn ru ro
#               Will create tables that block all requests from China, Russia and Romania
# Note:         To get a sorted list of the inserted IPSet IPs for example China list(cn) run the command:
#               ipset list cn | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4
# #############################################################################
# Defining some defaults
iptables="/sbin/iptables"
tempdir="/tmp"
sourceURL="http://www.ipdeny.com/ipblocks/data/countries/"
#
# Verifying that the program 'ipset' is installed
if ! (dpkg -l | grep '^ii  ipset' &>/dev/null); then
	echo "ERROR: 'ipset' package is not installed and required."
	echo "Please install it with the command 'apt install ipset' and start this script again"
	exit 1
fi
[ -e /sbin/ipset ] && ipset="/sbin/ipset" || ipset="/usr/sbin/ipset"
#
# Verifying the number of arguments
if [ $# -lt 1 ]; then
	echo "ERROR: wrong number of arguments. Must be at least one."
	echo "countries_block.bash countrycode [countrycode] ......"
	echo "Use the standard locale country codes to get the proper IP list. eg."
	echo "countries_block.bash cn ru ro"
	exit 2
fi
#
# Now load the rules for blocking each given countries and insert them into IPSet tables
for country; do
	# Read each line of the list and create the IPSet rules
	# Making sure only the valid country codes and lists are loaded
	if wget -q -P $tempdir ${sourceURL}"${country}".zone; then
		# Destroy the IPSet list if it exists
		$ipset flush "$country" &>/dev/null
		# Create the IPSet list name
		echo "Creating and filling the IPSet country list: $country"
		$ipset create "$country" hash:net &>/dev/null
		(for IP in $(cat $tempdir/${country}.zone); do
			# Create the IPSet rule from each IP in the list
			echo -n "$ipset add $country $IP --exist - "
			$ipset add $country $IP -exist && echo "OK" || echo "FAILED"
		done) >$tempdir/IPSet-rules.${country}.txt
		# Destroy the already existing rule if it exists and insert the new one
		$iptables -D INPUT -p tcp -m set --match-set $country src -j DROP &>/dev/null
		$iptables -I INPUT -p tcp -m set --match-set $country src -j DROP
		# Delete the temporary downloaded counties IP lists
		rm $tempdir/${country}.zone
	else
		echo "Argument $country is invalid or not available as country IP list. Skipping"
	fi
done
# Display the result of the iptables rules in INPUT chain
echo "======================================"
echo "IPSet lists registered in iptables:"
$iptables -L INPUT -n -v | grep 'match-set'
# Dispaly the number of IP ranges entered in the IPset lists
echo "--------------------------------------"
for country; do
	echo "Number of ip ranges entered in IPset list '$country' : $($ipset list "$country" | wc -l)"
done
echo "======================================"

exit 0
#
#eof
