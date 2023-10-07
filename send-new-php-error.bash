#!/usr/bin/env bash

# version 1.2.1
# © Sergey Voronov 2010
# © Nill Ringil 2010-2022

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/opt/bin:/snap/bin

eerror() {
        echo "$*"
        exit 1
}

TG_SEND=$(which telegram-send)

if [ ! -f "$TG_SEND" ]; then
        printf "ERROR: The telegram-send not installed.\n"
        printf "FIX: Please install telegram-send using pip(pip install telegram-send)\n"
        exit 1
fi

# do_loadconf

#LISTLOG=$(grep 'php_admin_value\[error_log\]' /etc/php/7.2/fpm/pool.d/* | grep -v ";" | grep -v dev| awk '{print $3}')

LISTLOG=/var/log/php/www.error.log

for LOG in $LISTLOG; do
        NAME=$(basename "$LOG")
        F=$LOG

        DIR=/tmp
        FLAG=$DIR/$NAME.cnt

        if [ ! -e "$F" ]; then
                #                echo "*** File $F does now exist, exiting…" ; exit 1
                exit 0
        fi

        if [ ! -e "$FLAG" ]; then
                touch "$FLAG"
        fi
        if [ ! -e "$FLAG" ]; then
                touch "$FLAG"
        fi

        CURR_N=$(wc -l "$F" | awk '{ print $1 }')
        LAST_N=$(cat "$FLAG")
#             echo "debug: CURR_N=$CURR_N LAST_N=$LAST_N FLAG=$FLAG F=$F NAME=$NAME"
        test -z "$LAST_N" && LAST_N=0

        if [ "$CURR_N" -gt "$LAST_N" ]; then

                let STR=$CURR_N-$LAST_N
                echo -e  "Log file \"$F\" has new lines ($LAST_N -> $CURR_N).\n $(tail -n $STR $F)" | $TG_SEND --stdin --disable-web-page-preview
        fi

        echo "$CURR_N" >"$FLAG"
done
