#!/usr/bin/env bash

# Check for the presence of curl
if ! command -v curl &> /dev/null; then
  # Check if apt is available
  if command -v apt &> /dev/null; then
    # Install curl using apt
    sudo apt update
    sudo apt install -y curl
  else
    echo "Install curl with the package manager of your distribution"
    echo "Instale o curl com o gerenciador de pacotes da sua distribuição"
    exit 255
  fi
fi

# Read ZONE_ID and API_KEY from /etc/cloudflare/env file
if [ -f /etc/cloudflare/env ]; then
  source /etc/cloudflare/env
else
  echo "The /etc/cloudflare/env file is missing. Please make sure it's set up."
  exit 1
fi

# Make a request to the Cloudflare API
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/security_level" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json")

# Check the response and exit accordingly
if [ -n "$response" ]; then
  security_level=$(echo "$response" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')
  if [ "$security_level" != "high" ]; then
    echo "The security level is not set to high."
    exit 0
  else
    echo "The security level is set correctly to high."
    exit 1
  fi
else
  echo "Failed to fetch security level information from Cloudflare API."
  exit 1
fi
