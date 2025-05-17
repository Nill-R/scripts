#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

set -euo pipefail

EXPECTED_ARGS=1
E_BADARGS=65
E_USERADD_FAILED=66
E_CHPASSWD_FAILED=67
E_PASSWORD_EMPTY=68

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root." >&2
  exit 1
fi

# Check for correct number of arguments
if [ $# -ne $EXPECTED_ARGS ]; then
  echo "Usage: $0 new_user_name" >&2
  exit $E_BADARGS
fi

NEW_USER_NAME="$1"

# Generate password
PASS=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w24 | head -n1)

if [ -z "$PASS" ]; then
    echo "Error: Failed to generate password." >&2
    exit $E_PASSWORD_EMPTY
fi

# Create user
if ! useradd -s /bin/bash -m "$NEW_USER_NAME"; then
    echo "Error: Failed to create user '$NEW_USER_NAME'." >&2
    exit $E_USERADD_FAILED
fi
echo "User '$NEW_USER_NAME' created successfully."

# Set password
if ! echo "$NEW_USER_NAME:$PASS" | chpasswd; then
    echo "Error: Failed to set password for user '$NEW_USER_NAME'." >&2
    # Consider rolling back user creation or other cleanup here if necessary
    exit $E_CHPASSWD_FAILED
fi
echo "Password for user '$NEW_USER_NAME' set successfully."

echo "----------------------------------------"
printf "Username: %s\n" "$NEW_USER_NAME"
printf "Password: %s\n" "$PASS"
echo "----------------------------------------"
echo "Script completed successfully."
