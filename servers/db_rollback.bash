#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Script created with Claude 3.7 Sonnet assistant(https://claude.ai) using self-hosted LibreChat

set -e

# Check for site name argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 domain.site"
    exit 1
fi

SITE_NAME="$1"
SITE_PATH="/srv/web/${SITE_NAME}"
BACKUP_PATH="/backup/mysql"

# Check for site directory
if [ ! -d "$SITE_PATH" ]; then
    echo "Error: Site directory $SITE_PATH does not exist"
    exit 1
fi

# Function to determine database name from config files
get_db_name() {
    local site_path="$1"
    local db_name=""
    
    # Check for WordPress
    if [ -f "${site_path}/wp-config.php" ]; then
        # Ignore commented lines (starting with // or /*)
        db_name=$(grep -v '^\s*\/\/' "${site_path}/wp-config.php" | grep -v '^\s*\/\*' | grep DB_NAME | grep -oP "define\(\s*'DB_NAME',\s*'[^']*'\s*\)" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        if [ -n "$db_name" ]; then
            echo "$db_name"
            return
        fi
    # Check for OpenCart
    elif [ -f "${site_path}/config.php" ]; then
        # Ignore commented lines for first format
        db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "'DB_DATABASE'" | grep -oP "'DB_DATABASE',\s*'[^']*'" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        
        # If not found, check alternative OpenCart format
        if [ -z "$db_name" ]; then
            db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "define('DB_DATABASE'" | grep -oP "define\('DB_DATABASE',\s*'[^']*'\)" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        fi
        
        # Another OpenCart variant
        if [ -z "$db_name" ]; then
            db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "db_database" | grep -oP "\['db_database'\]\s*=\s*'[^']*'" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        fi
        
        if [ -n "$db_name" ]; then
            echo "$db_name"
            return
        fi
    fi
    
    echo "Error: Database name not found"
    exit 1
}

# Get database name
DB_NAME=$(get_db_name "$SITE_PATH")
echo "Database found: $DB_NAME"

# Search for available backups
echo "Searching for backups for database $DB_NAME..."

# Search for all backup files with different extensions
BACKUPS=$(find "$BACKUP_PATH" -type f -name "${DB_NAME}-*.sql.*" | sort -r)

if [ -z "$BACKUPS" ]; then
    echo "Error: Backups for database $DB_NAME not found"
    exit 1
fi

# Select the last 5 backups
RECENT_BACKUPS=$(echo "$BACKUPS" | head -5)
BACKUP_COUNT=$(echo "$RECENT_BACKUPS" | wc -l)

echo "Found $BACKUP_COUNT recent backups:"

# Check for fzf
if command -v fzf >/dev/null 2>&1; then
    echo "Using fzf to select backup..."
    
    # Создаем массив с путями к бэкапам
    mapfile -t BACKUP_PATHS < <(echo "$RECENT_BACKUPS")
    
    # Создаем массив с именами файлов для отображения
    DISPLAY_NAMES=()
    for backup in "${BACKUP_PATHS[@]}"; do
        filename=$(basename "$backup")
        # Извлекаем дату из имени файла
        date_part=$(echo "$filename" | grep -oP "${DB_NAME}-\K[0-9]+" | head -1)
        
        # Форматируем дату, если она имеет ожидаемую длину
        if [ ${#date_part} -eq 12 ]; then
            year=${date_part:0:4}
            month=${date_part:4:2}
            day=${date_part:6:2}
            hour=${date_part:8:2}
            minute=${date_part:10:2}
            DISPLAY_NAMES+=("$filename (дата: ${year}-${month}-${day} ${hour}:${minute})")
        else
            DISPLAY_NAMES+=("$filename")
        fi
    done
    
    # Use fzf to select backup
    selected_idx=$(printf "%s\n" "${DISPLAY_NAMES[@]}" | fzf --height=40% --layout=reverse --border | grep -n "^" | cut -d ":" -f1)
    
    # Check if selection was made
    if [ -z "$selected_idx" ]; then
        echo "Selection not made, operation cancelled"
        exit 0
    fi
    
    # Array indices start at 0, while grep -n starts at 1
    selected_idx=$((selected_idx - 1))
    SELECTED_BACKUP="${BACKUP_PATHS[$selected_idx]}"
    
    echo "Selected backup: $(basename "$SELECTED_BACKUP")"
else
    # Standard selection by number
    # Display list of backups with numbers
    i=1
    while IFS= read -r backup; do
        filename=$(basename "$backup")
        # Extract date from filename
        date_part=$(echo "$filename" | grep -oP "${DB_NAME}-\K[0-9]+" | head -1)
        
        # Форматируем дату, если она имеет ожидаемую длину
        if [ ${#date_part} -eq 12 ]; then
            year=${date_part:0:4}
            month=${date_part:4:2}
            day=${date_part:6:2}
            hour=${date_part:8:2}
            minute=${date_part:10:2}
            echo "$i) $filename (дата: ${year}-${month}-${day} ${hour}:${minute})"
        else
            echo "$i) $filename"
        fi
        i=$((i+1))
    done <<< "$RECENT_BACKUPS"
    
    # Ask for user selection
    echo -n "Select backup number to restore (1-$BACKUP_COUNT) or 'q' to exit: "
    read choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Operation cancelled"
        exit 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$BACKUP_COUNT" ]; then
        echo "Invalid selection"
        exit 1
    fi
    
    # Get selected backup file
    SELECTED_BACKUP=$(echo "$RECENT_BACKUPS" | sed -n "${choice}p")
    echo "Selected backup: $(basename "$SELECTED_BACKUP")"
fi

# Ask for confirmation
echo -n "Are you sure you want to restore database $DB_NAME from this backup? (y/n): "
read confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation cancelled"
    exit 0
fi

# Determine compression type and restore database
echo "Restoring database $DB_NAME from backup..."

if [[ "$SELECTED_BACKUP" == *.zst ]]; then
    zstd -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
elif [[ "$SELECTED_BACKUP" == *.xz ]]; then
    xz -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
elif [[ "$SELECTED_BACKUP" == *.gz ]]; then
    gzip -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
else
    echo "Unknown backup compression format"
    exit 1
fi

echo "Database $DB_NAME successfully restored from backup $(basename "$SELECTED_BACKUP")"
