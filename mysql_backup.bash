#!/usr/bin/env bash

# This will dump all your databases
# MySQL backup script
# This script is licensed under GNU GPLv2 only

DATE=$(date +%Y%m%d%H%M)
BACKUP_PATH=/backup/mysql
MYSQLDUMP=$(which mysqldump)
COMP=$(which zstd)

if [ ! -f "$MYSQLDUMP" ]; then
        printf "ERROR: The mysqldump not installed.\n"
        printf "FIX: Please install mysqldump\n"
        exit 1
fi

if [ ! -f "$COMP" ]; then
        printf "ERROR: The zstd not installed.\n"
        printf "FIX: Please install zstd\n"
        exit 1
fi

for DB in $(echo "show databases" | mysql --defaults-file=/etc/mysql/debian.cnf -N); do
        $MYSQLDUMP --defaults-file=/etc/mysql/debian.cnf $DB >$BACKUP_PATH/${DB}_${DATE}.sql

        $COMP -19 --rm $BACKUP_PATH/${DB}_${DATE}.sql
done

# purge old dumps
find $BACKUP_PATH/ -name "*.sql*" -mtime +8 -exec rm -vf {} \;
