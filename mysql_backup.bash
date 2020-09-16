#!/usr/bin/env bash
# This will dump all your databases
# MySQL backup script
# This script is licensed under GNU GPLv2+
DATE=$(date +%Y%m%d%H%M)
BACKUP_PATH=/backup/mysql

for DB in $(echo "show databases" | mysql --defaults-file=/etc/mysql/debian.cnf -N); do
	mysqldump --defaults-file=/etc/mysql/debian.cnf $DB >$BACKUP_PATH/${DB}_${DATE}.sql

	xz -e $BACKUP_PATH/${DB}_${DATE}.sql
done

# purge old dumps
find $BACKUP_PATH/ -name "*.sql*" -mtime +8 -exec rm -vf {} \;
