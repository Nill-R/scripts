#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

EXPECTED_ARGS=2
E_BADARGS=65
MYSQL=$(which mysql)
PASS=$(openssl rand -base64 12)

Q1="CREATE DATABASE IF NOT EXISTS $1;"
Q2="CREATE USER '$2'@'localhost' IDENTIFIED BY '$PASS';"
Q3="GRANT ALL PRIVILEGES ON $1.* TO '$2'@'localhost';"
Q4="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}${Q4}"

if [ $# -ne $EXPECTED_ARGS ]; then
    echo "Usage: $0 dbname dbuser"
    exit $E_BADARGS
fi

$MYSQL -e "$SQL"

printf "db name: %s\n" "$1"
printf "db user: %s\n" "$2"
printf "db pass: %s\n" "$PASS"

exit 0
