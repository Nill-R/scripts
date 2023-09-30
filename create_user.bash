#!/usr/bin/env bash

EXPECTED_ARGS=1
E_BADARGS=65

PASS=$(tr -cd '[:alnum:]' </dev/urandom | fold -w24 | head -n1)

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ $# -ne $EXPECTED_ARGS ]; then
        echo "Usage: $0 new_user_name"
        exit $E_BADARGS
fi

useradd -s/bin/bash -m "$1"

echo "$1:$PASS"|chpasswd

printf "user: %s\n" "$1"
printf "password: %s\n" "$PASS"
