#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Read in the two dates
read -r -p "Enter the first date (YYYY-MM-DD): " date1
read -r -p "Enter the second date (YYYY-MM-DD): " date2

# Convert the dates to seconds since the epoch
date1_seconds=$(date -d "$date1" +%s)
date2_seconds=$(date -d "$date2" +%s)

# Calculate the difference in seconds
difference_seconds=$((date2_seconds - date1_seconds))

# Convert the difference to days
difference_days=$((difference_seconds / 86400))

# Output the result
echo "The number of days between $date1 and $date2 is $difference_days."
