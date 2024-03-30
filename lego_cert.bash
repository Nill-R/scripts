#!/usr/bin/env bash

# Function to display the usage of the script
#
# This function prints a message to the console with the usage instructions
# for the script. It takes no arguments and does not return any values.

display_usage() {
    # Print the usage instructions
    echo -e "Usage: $(basename $0)" # Use $0 to get the script name
}

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/opt/bin:/snap/bin:~/bin

cd "$(mktemp -d /tmp/script.XXXXXXX)" || exit

TEMP_DIR=$(pwd)

ACTION=$1
LEGO=$(which lego)

if [ "$(id -u)" = 0 ]; then
        CONF_PATH="/etc"
else
        CONF_PATH="$HOME/.local/etc"
        mkdir -p "$CONF_PATH"
fi

if [ ! -f "$LEGO" ]; then
        printf "ERROR: The lego not installed.\n"
        printf "FIX: Please install lego\n"
        printf "FIX: https://github.com/go-acme/lego\n"
        rm -rf "$TEMP_DIR"
        exit 1
fi

if [ ! -d "$CONF_PATH"/lego ]; then
        echo -e "$CONF_PATH/lego does not exist plz create it and files in it\n"
        rm -rf "$TEMP_DIR"
        exit 1
fi

if [ -z "$(ls -A "$CONF_PATH"/lego/)" ]; then
   echo -e "$CONF_PATH/lego/ is empty" && exit 1
fi


for dir in "$CONF_PATH"/lego/*; do

source "$dir"

ACTION=run

if [ -d "$CONF_PATH"/letsencrypt/"$DOMAIN" ]; then
        ACTION=renew
fi

export LEGO_DISABLE_CNAME_SUPPORT=true

lego --dns "$DNS_PROVIDER" \
        --domains *."$DOMAIN" \
        --domains "$DOMAIN" \
        --email "$EMAIL" \
        --path="$CONF_PATH/letsencrypt/$DOMAIN" \
        --accept-tos "$ACTION"

done

cd ~ || exit

rm -rf "$TEMP_DIR"

nginx -t && systemctl restart nginx

exit 0
