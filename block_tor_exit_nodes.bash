#!/usr/bin/env bash

IPSET=$(which ipset)
IPTABLES=$(which iptables)

if [ ! -f "$IPSET" ]; then
	printf "ERROR: The ipset not installed.\n"
	printf "FIX: Please install ipset\n"
	printf "FIX: apt install ipset\n"
	exit 1
fi

if [ ! -f "$IPTABLES" ]; then
	printf "ERROR: The iptables not installed.\n"
	printf "FIX: Please install iptables\n"
	printf "FIX: apt install iptables\n"
	exit 1
fi

# create a new set for individual IP addresses
$IPSET -N tor iphash
# get a list of Tor exit nodes that can access $YOUR_IP, skip the comments and read line by line
wget -q https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$(curl -4 https://ifconfig.co) -O - | sed '/^#/d' | while read IP; do
	# add each IP address to the new set, silencing the warnings for IPs that have already been added
	$IPSET -q -A tor $IP
done
# filter our new set in iptables
$IPTABLES -A INPUT -m set --match-set tor src -j DROP
