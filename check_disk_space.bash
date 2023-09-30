#!/usr/bin/env bash

CURRENT_SPACE=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
CURRENT_INODES=$(df -i / | grep / | awk '{ print $5}' | sed 's/%//g')
THRESHOLD=90

if [ "$CURRENT_SPACE" -gt "$THRESHOLD" ] ; then
        telegram-send "Free space at $(hostname) server is ""$CURRENT_SPACE""%"
fi

if [ "$CURRENT_INODES" -gt "$THRESHOLD" ] ; then
        telegram-send "Free inodes at $(hostname) server is ""$CURRENT_INODES""%"
fi

exit 0
