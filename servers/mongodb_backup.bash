#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

#  This will dump all your databases
#  MongoDB backup script
#  This script is licensed under GNU GPLv2 only

DATE=$(date +%Y%m%d%H%M)
BACKUP_PATH=/backup/mongodb
MONGODUMP=$(which mongodump)

if [ ! -f "$MONGODUMP" ]; then
        printf "ERROR: The mongodump not installed.\n"
        printf "FIX: Please install mongodb-database-tools\n"
        exit 1
fi


for DB in $(mongo admin --quiet --eval 'db.getMongo().getDBNames().forEach(function(db){print(db)})'); do
        mongodump --db "$DB" --gzip --archive=$BACKUP_PATH/"$DATE"."$DB".mongodb.gz
done

# purge old dumps
find $BACKUP_PATH/ -name "*.gz" -mtime +8 -exec rm -vf {} \;

exit 0
