#!/usr/bin/env bash

SEC_LEVEL=$1

if [ $# -eq 0 ]; then
    >&2 echo "No argumet given. Set SEC_LEVEL to high"
    SEC_LEVEL=high
fi

ZONE_ID=
API_KEY=

curl --request PATCH \
  --url https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/security_level \
  --header 'Content-Type: application/json' \
  -H "Authorization: Bearer $API_KEY" \
  --data '{
  "value": "'$SEC_LEVEL'"
}'