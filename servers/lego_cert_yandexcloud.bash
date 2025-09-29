#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# Скрипт получения/обновления сертификатов через lego и Yandex.Cloud DNS

set -euo pipefail

LOG_FILE="/var/log/lego/yandex-cloud-cert.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >>"$LOG_FILE" 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [[ $# -ne 1 ]]; then
    log "Usage: $0 /etc/lego/domain.tld"
    exit 1
fi

VARS_FILE="$1"

if [[ ! -f "$VARS_FILE" ]]; then
    log "ERROR: Variables file not found: $VARS_FILE"
    exit 1
fi

# --- Загружаем переменные ---
source "$VARS_FILE"

# --- Проверяем обязательные переменные ---
: "${DOMAIN:?ERROR: DOMAIN не задан в $VARS_FILE}"
: "${YANDEX_CLOUD_FOLDER_ID:?ERROR: YANDEX_CLOUD_FOLDER_ID не задан}"
: "${YANDEX_CLOUD_SA_NAME:?ERROR: YANDEX_CLOUD_SA_NAME не задан}"
: "${EMAIL:?ERROR: EMAIL не задан}"

CERT_PATH="/etc/letsencrypt/certificates/$DOMAIN"
mkdir -p "$CERT_PATH"

LEGO=$(command -v lego || true)
if [ -z "$LEGO" ]; then
    log "ERROR: lego не найден, установи https://github.com/go-acme/lego"
    exit 1
fi

log "===== $(date '+%Y-%m-%d %H:%M:%S') Starting certificate check for $DOMAIN ====="

# --- Генерируем временный IAM key для lego ---
IAM_KEY_JSON=$(mktemp)
yc iam key create \
    --service-account-name "$YANDEX_CLOUD_SA_NAME" \
    --output "$IAM_KEY_JSON"

export YANDEX_CLOUD_IAM_TOKEN
YANDEX_CLOUD_IAM_TOKEN=$(base64 -w0 < "$IAM_KEY_JSON")
export YANDEX_CLOUD_FOLDER_ID

rm -f "$IAM_KEY_JSON"

# --- Определяем действие: run если сертификата нет, иначе renew ---
ACTION="renew"
if [ ! -d "$CERT_PATH" ] || [ -z "$(ls -A "$CERT_PATH")" ]; then
    log "Нет существующего сертификата, запускаю 'run'"
    ACTION="run"
else
    log "Пробую обновить сертификат (renew)"
fi

# --- Запускаем lego ---
set +e
$LEGO --email "$EMAIL" \
    --dns yandexcloud \
    --domains "$DOMAIN" \
    --domains "*.$DOMAIN" \
    --path "$CERT_PATH" \
    --accept-tos "$ACTION"
LEGO_EXIT=$?
set -e

if [ $LEGO_EXIT -ne 0 ]; then
    log "ERROR: lego завершился с ошибкой (код $LEGO_EXIT)"
    exit $LEGO_EXIT
fi

# --- Если был renew, проверяем и перезапускаем nginx ---
if [ "$ACTION" = "renew" ]; then
    if command -v nginx >/dev/null && command -v systemctl >/dev/null; then
        if nginx -t; then
            systemctl reload nginx
            log "nginx успешно перезапущен"
        else
            log "ERROR: Проверка nginx -t не прошла, nginx не перезапущен"
        fi
    else
        log "nginx или systemctl не найдены, пропускаю рестарт"
    fi
fi

log "Скрипт завершился успешно"
log "===== $(date '+%Y-%m-%d %H:%M:%S') Finished certificate check for $DOMAIN ====="
