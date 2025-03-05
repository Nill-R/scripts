#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# You need to set ZONE_ID and API_TOKEN in /etc/cloudflare/credentials file
# ZONE_ID=your_zone_id
# API_TOKEN=your_api_token

import requests

# Функция для чтения данных из файла
def read_credentials(filepath):
    credentials = {}
    with open(filepath, 'r') as file:
        for line in file:
            key, value = line.strip().split('=')
            credentials[key] = value
    return credentials

# Чтение данных из файла /etc/cloudflare/credentials
credentials = read_credentials('/etc/cloudflare/credentials')

zone_id = credentials.get("ZONE_ID")
api_token = credentials.get("API_TOKEN")

if not zone_id or not api_token:
    print("Ошибка: не удалось получить ZONE_ID или API_TOKEN из файла.")
    exit(1)

# URL для выполнения purge everything
url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache"

# Заголовки для авторизации
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}

# Тело запроса
data = {
    "purge_everything": True
}

# Выполнение запроса
response = requests.post(url, headers=headers, json=data)

# Проверка результата
if response.status_code == 200:
    print("Purge everything выполнен успешно.")
else:
    print(f"Ошибка при выполнении purge: {response.status_code} - {response.text}")
