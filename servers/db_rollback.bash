#!/usr/bin/env bash

# Script created with Claude 3.7 Sonnet assistant(https://claude.ai) using self-hosted LibreChat

set -e

# Проверка наличия аргумента с именем сайта
if [ $# -ne 1 ]; then
    echo "Использование: $0 domain.site"
    exit 1
fi

SITE_NAME="$1"
SITE_PATH="/srv/web/${SITE_NAME}"
BACKUP_PATH="/backup/mysql"

# Проверка существования директории сайта
if [ ! -d "$SITE_PATH" ]; then
    echo "Ошибка: Директория сайта $SITE_PATH не существует"
    exit 1
fi

# Функция для определения имени базы данных из конфигов
get_db_name() {
    local site_path="$1"
    local db_name=""
    
    # Проверка на WordPress
    if [ -f "${site_path}/wp-config.php" ]; then
        # Игнорируем закомментированные строки (начинающиеся с // или /*)
        db_name=$(grep -v '^\s*\/\/' "${site_path}/wp-config.php" | grep -v '^\s*\/\*' | grep DB_NAME | grep -oP "define\(\s*'DB_NAME',\s*'[^']*'\s*\)" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        if [ -n "$db_name" ]; then
            echo "$db_name"
            return
        fi
    # Проверка на OpenCart
    elif [ -f "${site_path}/config.php" ]; then
        # Игнорируем закомментированные строки для первого формата
        db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "'DB_DATABASE'" | grep -oP "'DB_DATABASE',\s*'[^']*'" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        
        # Если не найдено, проверяем альтернативный формат OpenCart
        if [ -z "$db_name" ]; then
            db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "define('DB_DATABASE'" | grep -oP "define\('DB_DATABASE',\s*'[^']*'\)" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        fi
        
        # Еще один вариант для OpenCart
        if [ -z "$db_name" ]; then
            db_name=$(grep -v '^\s*\/\/' "${site_path}/config.php" | grep -v '^\s*\/\*' | grep "db_database" | grep -oP "\['db_database'\]\s*=\s*'[^']*'" | grep -oP "'[^']*'" | grep -oP "[^']*" | tail -1)
        fi
        
        if [ -n "$db_name" ]; then
            echo "$db_name"
            return
        fi
    fi
    
    echo "Не удалось определить имя базы данных"
    exit 1
}

# Получаем имя базы данных
DB_NAME=$(get_db_name "$SITE_PATH")
echo "Обнаружена база данных: $DB_NAME"

# Ищем доступные бэкапы
echo "Поиск бэкапов для базы данных $DB_NAME..."

# Ищем все файлы бэкапов с разными расширениями
BACKUPS=$(find "$BACKUP_PATH" -type f -name "${DB_NAME}-*.sql.*" | sort -r)

if [ -z "$BACKUPS" ]; then
    echo "Бэкапы для базы данных $DB_NAME не найдены"
    exit 1
fi

# Выбираем последние 5 бэкапов
RECENT_BACKUPS=$(echo "$BACKUPS" | head -5)
BACKUP_COUNT=$(echo "$RECENT_BACKUPS" | wc -l)

echo "Найдено $BACKUP_COUNT последних бэкапов:"

# Проверяем наличие fzf
if command -v fzf >/dev/null 2>&1; then
    echo "Используем fzf для выбора бэкапа..."
    
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
    
    # Используем fzf для выбора
    selected_idx=$(printf "%s\n" "${DISPLAY_NAMES[@]}" | fzf --height=40% --layout=reverse --border | grep -n "^" | cut -d ":" -f1)
    
    # Проверяем, был ли сделан выбор
    if [ -z "$selected_idx" ]; then
        echo "Выбор не сделан, операция отменена"
        exit 0
    fi
    
    # Индексы в массиве начинаются с 0, а grep -n с 1
    selected_idx=$((selected_idx - 1))
    SELECTED_BACKUP="${BACKUP_PATHS[$selected_idx]}"
    
    echo "Выбран бэкап: $(basename "$SELECTED_BACKUP")"
else
    # Стандартный выбор по номеру
    # Выводим список бэкапов с номерами
    i=1
    while IFS= read -r backup; do
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
            echo "$i) $filename (дата: ${year}-${month}-${day} ${hour}:${minute})"
        else
            echo "$i) $filename"
        fi
        i=$((i+1))
    done <<< "$RECENT_BACKUPS"
    
    # Запрашиваем выбор пользователя
    echo -n "Выберите номер бэкапа для восстановления (1-$BACKUP_COUNT) или 'q' для выхода: "
    read choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Операция отменена"
        exit 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$BACKUP_COUNT" ]; then
        echo "Некорректный выбор"
        exit 1
    fi
    
    # Получаем выбранный файл бэкапа
    SELECTED_BACKUP=$(echo "$RECENT_BACKUPS" | sed -n "${choice}p")
    echo "Выбран бэкап: $(basename "$SELECTED_BACKUP")"
fi

# Запрашиваем подтверждение
echo -n "Вы уверены, что хотите восстановить базу данных $DB_NAME из этого бэкапа? (y/n): "
read confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Операция отменена"
    exit 0
fi

# Определяем тип сжатия и восстанавливаем базу
echo "Восстановление базы данных $DB_NAME из бэкапа..."

if [[ "$SELECTED_BACKUP" == *.zst ]]; then
    zstd -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
elif [[ "$SELECTED_BACKUP" == *.xz ]]; then
    xz -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
elif [[ "$SELECTED_BACKUP" == *.gz ]]; then
    gzip -dc "$SELECTED_BACKUP" | mysql "$DB_NAME"
else
    echo "Неизвестный формат сжатия бэкапа"
    exit 1
fi

echo "База данных $DB_NAME успешно восстановлена из бэкапа $(basename "$SELECTED_BACKUP")"
