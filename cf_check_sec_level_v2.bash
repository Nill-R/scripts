#!/bin/bash

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    # Check if apt is installed
    if command -v apt &> /dev/null; then
        # Install curl using apt
        sudo apt install -y curl
    else
        # Print error message in English and Portuguese
        echo "Install curl with the package manager of your distribution"
        echo "Instale curl com o gerenciador de pacotes da sua distribuição"
        exit 255
    fi
fi

# Check if env file exists
if [ ! -f "/etc/cloudflare/env" ]; then
    echo "The /etc/cloudflare/env file does not exist"
    exit 255
fi

# Read ZONE_ID and API_KEY from /etc/cloudflare/env file
source /etc/cloudflare/env

# Check if ZONE_ID and API_KEY variables are set
if [ -z "$ZONE_ID" ] || [ -z "$API_KEY" ]; then
    echo "ZONE_ID or API_KEY variables are not set in /etc/cloudflare/env file"
    exit 255
fi

# Make request to Cloudflare API using curl
response=$(curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/security_level")

# Check if request was successful
if [ $? -ne 0 ]; then
    echo "Error occurred while making API request"
    exit 255
fi

# Extract security level from response using sed and grep
security_level=$(echo "$response" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')

# Check if security level is not "high"
if [ "$security_level" != "high" ]; then
    echo "Security level is not set to high"
    exit 0
else
    echo "Security level is set to high"
    exit 1
fi
