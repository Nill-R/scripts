#!/usr/bin/env bash

EXPECTED_ARGS=2
E_BADARGS=65
MYSQL=$(which mysql)
PASS=$(tr -cd '[:alnum:]' </dev/urandom | fold -w24 | head -n1)

Q1="CREATE DATABASE IF NOT EXISTS $1;"
Q2="GRANT USAGE ON *.* TO $2@localhost IDENTIFIED BY '$PASS';"
Q3="GRANT ALL PRIVILEGES ON $1.* TO $2@localhost;"
Q4="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}${Q4}"

if [ $# -ne $EXPECTED_ARGS ]; then
	echo "Usage: $0 dbname dbuser"
	exit $E_BADARGS
fi
$MYSQL -e "$SQL"

printf "db name: $1\n"
printf "db user: $2\n"
printf "db pass: $PASS\n"

exit 0
