#!/usr/bin/env bash

PROD_PATH=/srv/web/prod
STAGE_PATH=/srv/web/stage
DATE=$(date +%Y%m%d%H%M)

cd $PROD_PATH
/usr/local/bin/wp --allow-root db export /tmp/$DATE.sql
cd $STAGE_PATH
/usr/local/bin/wp --allow-root db import /tmp/$DATE.sql
/usr/local/bin/wp --allow-root search-replace 'https://domain.tld' 'https://stage.domain.tld'
rm -rf /tmp/$DATE.sql

exit 0
