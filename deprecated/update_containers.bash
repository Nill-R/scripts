#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# Define the base directory
base_dir="/opt/docker-compose/"

# Get a list of subdirectories in the base directory
subdirs=$(find "$base_dir" -mindepth 1 -maxdepth 1 -type d)

# Loop through each subdirectory
for subdir in $subdirs; do
  echo "Processing directory: $subdir"
  # Change to the subdirectory
  cd "$subdir" || continue
  # Pull the latest images, recreate containers, and prune old images
  docker compose pull && docker compose up -d --force-recreate && docker image prune -a -f
done
