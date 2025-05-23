#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# MySQL backup script
# This script is licensed under GNU GPLv2 only

DATE=$(date +%Y%m%d%H%M)
BACKUP_PATH=/backup/mysql
MYSQLDUMP=$(which mysqldump)
COMP=$(which gzip)
#MYSQL_USER="your_mysql_username"
#MYSQL_PASSWORD="your_mysql_password"

# Check if required commands are available
check_commands() {
    if [ ! -x "$MYSQLDUMP" ]; then
        echo "ERROR: The mysqldump command is not available or executable."
        echo "Please make sure mysqldump is installed and accessible in your PATH."
        exit 1
    fi

    if [ ! -x "$COMP" ]; then
        echo "ERROR: The gzip command is not available or executable."
        echo "Please make sure gzip is installed and accessible in your PATH."
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
        "$MYSQLDUMP" --single-transaction --routines --triggers --events "$db" | "$COMP" > "$BACKUP_PATH/$db-$DATE.sql.gz"
    done
}

# Purge old backups
purge_old_backups() {
    echo "Purging backups older than 8 days..."
    find "$BACKUP_PATH" -name '*.sql.gz' -type f -mtime +8 -exec rm -vf {} \;
}

# Main function
main() {
    check_commands
    create_backup_dir
    backup_databases
    purge_old_backups
    echo "Backup completed successfully."
}

main
