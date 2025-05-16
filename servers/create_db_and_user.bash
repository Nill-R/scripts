#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

set -euo pipefail  # Добавим немного безопасности

EXPECTED_ARGS=2
E_BADARGS=65

# Проверяем какой клиент доступен
if command -v mariadb >/dev/null 2>&1; then
    DB_CLIENT=$(command -v mariadb)
else
    DB_CLIENT=$(command -v mysql)
fi

# Генерируем более надёжный пароль (увеличила длину)
PASS=$(openssl rand -base64 16)

# Проверка аргументов
if [ $# -ne $EXPECTED_ARGS ]; then
    echo "Usage: $0 dbname dbuser" >&2
    exit $E_BADARGS
fi

# Валидация входных данных
if [[ ! "$1" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ! "$2" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: Database name and user can only contain alphanumeric characters and underscores" >&2
    exit 1
fi

# SQL-запросы с правильным экранированием
Q1="CREATE DATABASE IF NOT EXISTS \`$1\`;"
Q2="CREATE USER '$2'@'localhost' IDENTIFIED BY '$PASS';"
Q3="GRANT ALL PRIVILEGES ON \`$1\`.* TO '$2'@'localhost';"
Q4="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}${Q4}"

# Выполняем запросы
if ! $DB_CLIENT -e "$SQL"; then
    echo "Error: Database operations failed" >&2
    exit 1
fi

# Выводим информацию в более структурированном виде
cat << EOF
Database created successfully!
------------------------
Database name: $1
Username: $2
Password: $PASS
------------------------
EOF

exit 0
