#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# MySQL backup script


DATE=$(date +%Y%m%d%H%M)
BACKUP_PATH=/backup/mysql
MYSQLDUMP=$(which mysqldump)
COMP=$(which zstd)
DAYS=8
#MYSQL_USER="your_mysql_username"
#MYSQL_PASSWORD="your_mysql_password"

# Parse command line arguments
parse_args() {
    if [ "$1" = "--days" ]; then
        if [ -n "$2" ] && [ "$2" -ge 0 ]; then
            DAYS=$2
            if [ "$DAYS" -eq 0 ]; then
                DAYS=8
            fi
        else
            echo "ERROR: Invalid or missing value for --days option."
            exit 1
        fi
    fi
}

# Check if required commands are available
check_commands() {
    if [ ! -x "$MYSQLDUMP" ]; then
        echo "ERROR: The mysqldump command is not available or executable."
        echo "Please make sure mysqldump is installed and accessible in your PATH."
        exit 1
    fi

    if [ ! -x "$COMP" ]; then
        echo "ERROR: The zstd command is not available or executable."
        echo "Please make sure zstd is installed and accessible in your PATH."
        exit 1
    fi
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    mkdir -p "$BACKUP_PATH"
}

# Backup each database individually
backup_databases() {
    databases=$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
    for db in $databases; do
        echo "Backing up database: $db"
        "$MYSQLDUMP" --single-transaction --routines --triggers --events "$db" > "$BACKUP_PATH/$db-$DATE.sql"
        "$COMP" -T0 -19 --rm "$BACKUP_PATH/$db-$DATE.sql"

    done
}

# Purge old backups
purge_old_backups() {
    echo "Purging backups older than $DAYS days..."
    find "$BACKUP_PATH" -name '*.sql.*' -type f -mtime +$DAYS -exec rm -vf {} \;
}

# Main function
main() {
    parse_args "$@"
    check_commands
    create_backup_dir
    backup_databases
    purge_old_backups
    echo "Backup completed successfully."
}

main
