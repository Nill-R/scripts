#!/usr/bin/env bash

GW_DEFAULT="192.168.1.1" # Main gateway
IF_DEFAULT="eth1"        # Main interface
GW_BACKUP="192.168.2.1"  # Backup gateway
IF_BACKUP="eth2"         # Backup interface
IP_CHECK="1.1.1.1"

GW_CURRENT=$(ip r s | grep default | awk '{print $3}')
PINGS=$(ping -c 5 -i .5 -w 6 ${IP_CHECK} | grep "icmp_seq=" | wc -l)

if [ "${GW_CURRENT}" == "${GW_DEFAULT}" ]; then
	if [ "${PINGS}" -le "3" ]; then
		echo "Switching to backup gateway"
		ip r r default via ${GW_BACKUP}
	fi
else
	if [ "${PINGS}" -gt "3" ]; then
		echo "Switching back to primary gateway"
		ip r r default via ${GW_DEFAULT}
	fi
fi

exit 0
