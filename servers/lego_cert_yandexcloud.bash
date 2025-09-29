#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# Массовая выдача/обновление сертификатов lego + Yandex.Cloud DNS
# Обрабатывает все файлы в /etc/lego/*. Каждый файл должен экспортировать/устанавливать переменные:
#   DOMAIN, EMAIL, YANDEX_CLOUD_FOLDER_ID
# Варианты для авторизации (поддерживаются все):
#   - YANDEX_CLOUD_IAM_TOKEN (base64 JSON)  -- прямо в файле
#   - YANDEX_CLOUD_IAM_TOKEN_FILE=/path/to/file  -- lego примет файл
#   - YANDEX_CLOUD_SA_KEY_FILE=/path/to/key.json  -- скрипт сделает base64 и экспортирует YANDEX_CLOUD_IAM_TOKEN
#   - YANDEX_CLOUD_SA_NAME=my-sa  -- скрипт вызовет `yc iam key create` и сформирует YANDEX_CLOUD_IAM_TOKEN
#
# Документация lego: YANDEX_CLOUD_FOLDER_ID и YANDEX_CLOUD_IAM_TOKEN (_FILE) используются lego. :contentReference[oaicite:1]{index=1}

set -u
set -o pipefail

LEGO_BIN="$(command -v lego || true)"
YC_BIN="$(command -v yc || true)"
NGINX_BIN="$(command -v nginx || true)"
SYSTEMCTL_BIN="$(command -v systemctl || true)"

LEGO_DIR="/etc/lego"
CERT_DIR_BASE="/etc/letsencrypt/certificates"
LOG_FILE="/var/log/lego/yandex-cloud-cert.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
exec >>"$LOG_FILE" 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# safe source with CRLF handling
safe_source() {
    local f="$1"
    if [ ! -f "$f" ]; then
        return 1
    fi
    if grep -q $'\r' "$f"; then
        local tmp
        tmp="$(mktemp)"
        tr -d '\r' < "$f" > "$tmp"
        # shellcheck source=/dev/null
        source "$tmp"
        rm -f "$tmp"
    else
        # shellcheck source=/dev/null
        source "$f"
    fi
    return 0
}

overall_status=0

if [ -z "$LEGO_BIN" ]; then
    log "ERROR: lego not found in PATH. Install go-acme/lego."
    exit 2
fi

log "Starting bulk lego Yandex.Cloud processing (dir: $LEGO_DIR)"

for varsfile in "$LEGO_DIR"/*; do
    [ -f "$varsfile" ] || continue
    log "===== Processing $varsfile ====="

    # unset previously set variables to avoid leaking between files
    unset DOMAIN EMAIL YANDEX_CLOUD_FOLDER_ID YANDEX_CLOUD_IAM_TOKEN \
          YANDEX_CLOUD_IAM_TOKEN_FILE YANDEX_CLOUD_SA_KEY_FILE YANDEX_CLOUD_SA_NAME || true

    if ! safe_source "$varsfile"; then
        log "ERROR: cannot source $varsfile, skipping"
        overall_status=1
        continue
    fi

    # basic required variables
    if [ -z "${DOMAIN:-}" ] || [ -z "${EMAIL:-}" ] || [ -z "${YANDEX_CLOUD_FOLDER_ID:-}" ]; then
        log "ERROR: missing required variables in $varsfile (need DOMAIN, EMAIL, YANDEX_CLOUD_FOLDER_ID). Skipping."
        overall_status=1
        continue
    fi

    CERT_PATH="$CERT_DIR_BASE/$DOMAIN"
    mkdir -p "$CERT_PATH"

    # prepare auth for lego
    # Priority:
    # 1) YANDEX_CLOUD_IAM_TOKEN (already provided)
    # 2) YANDEX_CLOUD_IAM_TOKEN_FILE (export as-is; lego will read)
    # 3) YANDEX_CLOUD_SA_KEY_FILE (local JSON key -> base64 -> YANDEX_CLOUD_IAM_TOKEN)
    # 4) YANDEX_CLOUD_SA_NAME (use yc iam key create -> base64 -> YANDEX_CLOUD_IAM_TOKEN)
    export YANDEX_CLOUD_FOLDER_ID="$YANDEX_CLOUD_FOLDER_ID"  # always export

    created_temp_keyfile=""
    if [ -n "${YANDEX_CLOUD_IAM_TOKEN:-}" ]; then
        export YANDEX_CLOUD_IAM_TOKEN
        log "Using YANDEX_CLOUD_IAM_TOKEN from $varsfile"
    elif [ -n "${YANDEX_CLOUD_IAM_TOKEN_FILE:-}" ]; then
        # ensure file exists
        if [ -f "$YANDEX_CLOUD_IAM_TOKEN_FILE" ]; then
            export YANDEX_CLOUD_IAM_TOKEN_FILE
            log "Using YANDEX_CLOUD_IAM_TOKEN_FILE=$YANDEX_CLOUD_IAM_TOKEN_FILE"
        else
            log "ERROR: YANDEX_CLOUD_IAM_TOKEN_FILE='$YANDEX_CLOUD_IAM_TOKEN_FILE' not found, skipping $DOMAIN"
            overall_status=1
            continue
        fi
    elif [ -n "${YANDEX_CLOUD_SA_KEY_FILE:-}" ]; then
        if [ -f "$YANDEX_CLOUD_SA_KEY_FILE" ]; then
            YANDEX_CLOUD_IAM_TOKEN="$(base64 -w0 < "$YANDEX_CLOUD_SA_KEY_FILE")"
            export YANDEX_CLOUD_IAM_TOKEN
            log "Generated YANDEX_CLOUD_IAM_TOKEN from YANDEX_CLOUD_SA_KEY_FILE"
        else
            log "ERROR: YANDEX_CLOUD_SA_KEY_FILE='$YANDEX_CLOUD_SA_KEY_FILE' not found, skipping $DOMAIN"
            overall_status=1
            continue
        fi
    elif [ -n "${YANDEX_CLOUD_SA_NAME:-}" ]; then
        if [ -z "$YC_BIN" ]; then
            log "ERROR: yc CLI not found, cannot create IAM key for service account '$YANDEX_CLOUD_SA_NAME'. Skipping $DOMAIN"
            overall_status=1
            continue
        fi
        TMP_KEY_JSON="$(mktemp)"
        if ! yc iam key create --service-account-name "$YANDEX_CLOUD_SA_NAME" --output "$TMP_KEY_JSON" >/dev/null 2>&1; then
            log "ERROR: yc iam key create failed for service account '$YANDEX_CLOUD_SA_NAME' (file: $TMP_KEY_JSON). Skipping $DOMAIN"
            rm -f "$TMP_KEY_JSON"
            overall_status=1
            continue
        fi
        YANDEX_CLOUD_IAM_TOKEN="$(base64 -w0 < "$TMP_KEY_JSON")"
        export YANDEX_CLOUD_IAM_TOKEN
        created_temp_keyfile="$TMP_KEY_JSON"
        log "Created temporary IAM key for service account '$YANDEX_CLOUD_SA_NAME' and exported YANDEX_CLOUD_IAM_TOKEN"
    else
        log "ERROR: no valid Yandex auth provided in $varsfile (need YANDEX_CLOUD_IAM_TOKEN or YANDEX_CLOUD_SA_NAME or YANDEX_CLOUD_SA_KEY_FILE). Skipping $DOMAIN"
        overall_status=1
        continue
    fi

    # decide action: run if no cert yet, else renew
    ACTION="renew"
    if [ ! -f "$CERT_PATH/certificates/$DOMAIN.crt" ]; then
        ACTION="run"
        log "No existing certificate found, will perform 'run'"
    else
        log "Existing certificate found, will attempt 'renew'"
    fi

    # run lego
    log "Running lego for $DOMAIN (action=$ACTION)"
    # capture output but don't allow set -e to kill the whole script
    set +e
    export LEGO_DISABLE_CNAME_SUPPORT=true
    "$LEGO_BIN" --email "$EMAIL" --dns yandexcloud \
        --domains "$DOMAIN" --domains "*.$DOMAIN" --path "$CERT_PATH" --accept-tos --dns.resolvers 1.1.1.1 "$ACTION" 2>&1 | sed -u 's/^/[lego] /' | tee -a "$LOG_FILE"
    lego_rc=${PIPESTATUS[0]}
    set -e 2>/dev/null || true

    # cleanup temp key if created
    if [ -n "$created_temp_keyfile" ]; then
        rm -f "$created_temp_keyfile"
        unset YANDEX_CLOUD_IAM_TOKEN
    fi

    if [ "$lego_rc" -ne 0 ]; then
        log "ERROR: lego failed for $DOMAIN (exit $lego_rc). See logs above."
        overall_status=1
        continue
    fi

    # only if renew: check nginx config and reload
    if [ "$ACTION" = "renew" ]; then
        if [ -n "$NGINX_BIN" ] && [ -n "$SYSTEMCTL_BIN" ]; then
            log "Checking nginx config (nginx -t)"
            if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
                log "nginx -t ok, reloading nginx"
                if systemctl reload nginx 2>&1 | tee -a "$LOG_FILE"; then
                    log "nginx reloaded successfully after $DOMAIN renewal"
                else
                    log "ERROR: systemctl reload nginx failed after $DOMAIN renewal"
                    overall_status=1
                fi
            else
                log "ERROR: nginx -t failed after $DOMAIN renewal; not reloading nginx"
                overall_status=1
            fi
        else
            log "nginx or systemctl not found, skipping reload"
        fi
    fi

    log "Finished processing $DOMAIN"
done

if [ "$overall_status" -ne 0 ]; then
    log "One or more domains failed during processing. Exit code: $overall_status"
else
    log "All domains processed successfully."
fi

exit "$overall_status"
