#!/usr/bin/env bash

display_usage() {
    printf "Usage: $(basename %s) directory for monitoring\n" "$0"
}

DIR_PATH=$1
if [ $# -eq 0 ]; then
    display_usage
    exit 1
fi
while true
do
        DATE=$(date +%Y%m%d-%H%M%S)
        inotifywait -e modify,attrib,close_write,create,delete,delete_self -r $1 -o /tmp/$DATE.inotifywait.log
        telegram-send "$(cat /tmp/$DATE.inotifywait.log) was changed at $(hostname) on $DATE"
        rm /tmp/$DATE.inotifywait.log
done
