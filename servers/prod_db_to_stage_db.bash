#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

PROD_PATH=/srv/web/prod
STAGE_PATH=/srv/web/stage
DATE=$(date +%Y%m%d%H%M)

cd "$PROD_PATH" || exit 1
/usr/local/bin/wp --allow-root db export "/tmp/$DATE.sql"
cd "$STAGE_PATH" || exit 1
/usr/local/bin/wp --allow-root db import "/tmp/$DATE.sql"
/usr/local/bin/wp --allow-root search-replace 'https://domain.tld' 'https://stage.domain.tld'
rm -f "/tmp/$DATE.sql"

exit 0
