#!/usr/bin/env bash

display_usage() {
    printf "Usage: $(basename $0) dns_provider_name domain action\n"
}

DNS_PROVIDER=$1
DOMAIN=$2
ACTION=$3
LEGO=$(which lego)

if [ $(id -u) = 0 ]; then
   CONF_PATH="/etc"
   else
   CONF_PATH="$HOME/.local/etc"
   mkdir -p $CONF_PATH
fi

DNS_PROVIDER_CREDENTIALS="$CONF_PATH/lego/$DNS_PROVIDER"

if [ $# -eq 0 ]; then
    display_usage
    exit 1
fi

if [ -d $DNS_PROVIDER ]; then
        printf "DNS provider does not set!\n"
        exit 1
fi

if [ -d $DOMAIN ]; then
        printf "Domain does not set!\n"
        exit 1
fi

if [ -d $ACTION ]; then
        printf "Action does not set!\n"
        exit 1
fi

if [ ! -f "$LEGO" ]; then
        printf "ERROR: The lego not installed.\n"
        printf "FIX: Please install lego\n"
        printf "FIX: https://github.com/go-acme/lego\n"
        exit 1
fi

if [ ! -f "$DNS_PROVIDER_CREDENTIALS" ]; then
        printf "ERROR: File with DNS provider credentials is absent.\n"
        printf "FIX: Please create file with credentials\n"
        exit 1
fi

source $DNS_PROVIDER_CREDENTIALS

lego --dns $DNS_PROVIDER \
     --domains *.$DOMAIN \
     --domains $DOMAIN \
     --email $EMAIL \
     --path="$CONF_PATH/letsencrypt/$DOMAIN" \
     --accept-tos $ACTION
