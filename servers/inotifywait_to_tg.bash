#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

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
        DATE=$(date +%d%m%Y%-%H%M%S)
        inotifywait -e modify,attrib,close_write,create,delete,delete_self -r "$DIR_PATH" -o /tmp/"$DATE".inotifywait.log
        telegram-send "$(cat /tmp/"$DATE".inotifywait.log) was changed at $(hostname) on $DATE"
        rm /tmp/"$DATE".inotifywait.log
done

exit 0
