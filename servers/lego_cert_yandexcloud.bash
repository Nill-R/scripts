#!/usr/bin/env bash
set -uo pipefail

LEGO_BIN="/usr/local/bin/lego"
LEGO_DIR="/etc/lego"
CERT_DIR_BASE="/etc/letsencrypt/certificates"
LOG_FILE="/var/log/lego_cert_yandexcloud.log"

log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $*" | tee -a "$LOG_FILE"
}

for file in "$LEGO_DIR"/*; do
    [ -f "$file" ] || continue

    log "=====" "Processing $file ====="

    # Сбрасываем переменные перед загрузкой нового файла
    unset DOMAIN EMAIL YANDEX_CLOUD_FOLDER_ID YANDEX_CLOUD_SA_NAME

    # Загружаем переменные из файла
    source "$file"

    # Проверяем что заданы обязательные переменные
    if [[ -z "${DOMAIN:-}" || -z "${YANDEX_CLOUD_FOLDER_ID:-}" || -z "${YANDEX_CLOUD_SA_NAME:-}" || -z "${EMAIL:-}" ]]; then
        log "ERROR" "Пропущены обязательные переменные в $file (DOMAIN, YANDEX_CLOUD_FOLDER_ID, YANDEX_CLOUD_SA_NAME, EMAIL)"
        continue
    fi

    CERT_DIR="$CERT_DIR_BASE/$DOMAIN"
    mkdir -p "$CERT_DIR"

    # Путь к ключу и сертификату
    KEY_FILE="$CERT_DIR/key.pem"
    CERT_FILE="$CERT_DIR/cert.pem"
    FULLCHAIN_FILE="$CERT_DIR/fullchain.pem"

    # Запускаем lego renew
    if "$LEGO_BIN" \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --path "$CERT_DIR" \
        --dns yandexcloud \
        --dns.resolvers 8.8.8.8:53 \
        --yandexcloud-folder-id "$YANDEX_CLOUD_FOLDER_ID" \
        --yandexcloud-service-account-name "$YANDEX_CLOUD_SA_NAME" \
        renew --days 30 --reuse-key --no-random-sleep 2>&1 | tee -a "$LOG_FILE"; then
        
        log "INFO" "Успешно обновлён сертификат для $DOMAIN"

        # Проверка nginx перед перезапуском
        if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
            nginx -s reload
            log "INFO" "nginx перезапущен после обновления $DOMAIN"
        else
            log "ERROR" "nginx -t провалился, сертификат $DOMAIN получен, но nginx не перезапущен"
        fi
    else
        log "ERROR" "Ошибка при обновлении сертификата для $DOMAIN"
    fi
done
