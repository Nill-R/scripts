#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Monthly MySQL / MariaDB backup script

set -euo pipefail

DATE=$(date +%Y%m%d)
BACKUP_PATH=/backup/mysql-monthly
MYSQLDUMP=$(which mariadb-dump || which mysqldump)
MYSQL_CMD=$(which mariadb || which mysql)
COMP=$(which zstd)

MONTHS=24

# Parse command line arguments
parse_args() {
    if [ "${1:-}" = "--months" ]; then
        if [ -n "${2:-}" ] && [ "$2" -ge 1 ]; then
            MONTHS="$2"
        else
            echo "ERROR: Invalid or missing value for --months option."
            exit 1
        fi
    fi
}

check_commands() {
    for bin in "$MYSQLDUMP" "$MYSQL_CMD" "$COMP"; do
        if [ ! -x "$bin" ]; then
            echo "ERROR: Required command not found or not executable: $bin"
            exit 1
        fi
    done
}

create_backup_dir() {
    mkdir -p "$BACKUP_PATH"
}

backup_databases() {
    databases=$("$MYSQL_CMD" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
    for db in $databases; do
        echo "Backing up database: $db"
        outfile="$BACKUP_PATH/$db-$DATE.sql"
        "$MYSQLDUMP" --single-transaction --routines --triggers --events "$db" > "$outfile"
        "$COMP" -T0 --rm "$outfile"
    done
}

purge_old_backups() {
    echo "Purging backups older than $MONTHS months..."

    cutoff=$(date -d "-$MONTHS months" +%Y%m%d)

    find "$BACKUP_PATH" -type f -name '*.sql.*' | while read -r file; do
        base=$(basename "$file")

        # выдёргиваем YYYYMMDD из имени
        if [[ $base =~ -([0-9]{8})\.sql ]]; then
            filedate="${BASH_REMATCH[1]}"
            if [ "$filedate" -lt "$cutoff" ]; then
                rm -vf "$file"
            fi
        fi
    done
}

main() {
    parse_args "$@"
    check_commands
    create_backup_dir
    backup_databases
    purge_old_backups
    echo "Monthly backup completed successfully."
}

main "$@"
