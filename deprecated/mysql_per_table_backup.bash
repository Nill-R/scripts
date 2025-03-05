#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# MySQL per table backup script

BACKUP=/path/to/backup/mysql-per-table
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
NOW=$(date +"%Y%d%m%H%M%S")
mkdir -p $BACKUP/$NOW
DBS="$($MYSQL -Bse 'show databases')"
for db in $DBS; do
	mkdir $BACKUP/$NOW/$db

	for i in $(echo "show tables" | $MYSQL $db | grep -v Tables_in_); do
		FILE=$BACKUP/$NOW/$db/$i.sql.xz
		echo $i
		$MYSQLDUMP --add-drop-table --allow-keywords -q -c $db $i | xz -e >$FILE
	done
done

exit 0
