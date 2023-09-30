#!/usr/bin/env bash

# This script writen by ChatGPT and don't testing!!!

# set the path to the file containing the domain names, one domain per line
filename="domains.txt"

# set the number of days to check for expiration
days_threshold=30

# set the Telegram bot token and chat ID to send messages
telegram_bot_token="<INSERT_BOT_TOKEN_HERE>"
telegram_chat_id="<INSERT_CHAT_ID_HERE>"

# read the domain names from the file
while read -r domain; do
    # get the top-level domain (TLD) of the domain
    tld=$(echo "$domain" | awk -F. '{print $NF}')

    # check if the TLD is "ru" or "рф" (Russian domains)
    if [[ "$tld" == "ru" || "$tld" == "рф" ]]; then
        # for "ru" and "рф" domains, get the expiration date using the "paid-till" field
        expiration_date=$(whois "$domain" | awk -F: '/paid-till:/ {print $2}' | xargs date +%s -d)
    else
        # for other domains, get the expiration date using the "Registry Expiry Date" field
        expiration_date=$(whois "$domain" | awk -F: '/Registry Expiry Date/ {print $2}' | xargs date +%s -d)
    fi

    # calculate the remaining days until expiration
    remaining_days=$(( ($expiration_date - $(date +%s)) / 86400 ))

    # check if the remaining days is less than or equal to the threshold
    if [[ "$remaining_days" -le "$days_threshold" ]]; then
        # send a Telegram message with the domain and the number of days remaining
        message="Domain $domain will expire in $remaining_days day(s)"
        curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
            -d chat_id="$telegram_chat_id" \
            -d text="$message"
    fi
done < "$filename"
