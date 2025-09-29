#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# Скрипт получения/обновления сертификатов через lego и Yandex.Cloud DNS

set -euo pipefail

LOG_FILE="/var/log/lego/yandex-cloud-cert.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

safe_source() {
    local file="$1"
    if [ -f "$file" ]; then
        if grep -q $'\r' "$file"; then
            log "WARNING: $file содержит CRLF, конвертирую в LF"
            local tmp_file
            tmp_file=$(mktemp)
            tr -d '\r' < "$file" > "$tmp_file"
            # shellcheck source=/dev/null
            source "$tmp_file"
            rm "$tmp_file"
        else
            # shellcheck source=/dev/null
            source "$file"
        fi
    else
        log "ERROR: Файл конфигурации $file не найден"
        exit 1
    fi
}

check_var() {
    if [ -z "${!1:-}" ]; then
        log "ERROR: Переменная $1 не задана в конфигурации"
        exit 1
    fi
}

LEGO=$(command -v lego || true)
if [ -z "$LEGO" ]; then
    log "ERROR: lego не найден, установи https://github.com/go-acme/lego"
    exit 1
fi

# читаем конфиг
CONF_FILE="/etc/lego/${DOMAIN:-}"
if [ -z "${DOMAIN:-}" ]; then
    log "ERROR: Переменная DOMAIN не передана окружением"
    exit 1
fi

safe_source "$CONF_FILE"

# проверяем обязательные переменные
check_var "DOMAIN"
check_var "YANDEX_CLOUD_FOLDER_ID"
check_var "YANDEX_CLOUD_SA_NAME"
check_var "EMAIL"

CERT_PATH="/etc/letsencrypt/certificates/$DOMAIN"
mkdir -p "$CERT_PATH"

# генерируем новый IAM key для lego
IAM_KEY_JSON=$(mktemp)
yc iam key create \
    --service-account-name "$YANDEX_CLOUD_SA_NAME" \
    --output "$IAM_KEY_JSON"

export YANDEX_CLOUD_IAM_TOKEN
YANDEX_CLOUD_IAM_TOKEN=$(base64 -w0 < "$IAM_KEY_JSON")
export YANDEX_CLOUD_FOLDER_ID

rm -f "$IAM_KEY_JSON"

ACTION="renew"
if [ ! -d "$CERT_PATH" ] || [ -z "$(ls -A "$CERT_PATH")" ]; then
    log "Нет существующего сертификата, запускаю 'run'"
    ACTION="run"
else
    log "Пробую обновить сертификат (renew)"
fi

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
exit 0
