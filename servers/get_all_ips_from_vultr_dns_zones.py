#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

import requests
import json
from typing import Set

def get_dns_records() -> Set[str]:
    # API-ключ нужно будет заменить на настоящий
    API_KEY = 'YOUR_VULTR_API_KEY'
    
    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'Content-Type': 'application/json'
    }

    # Сначала получим список всех DNS-доменов
    domains_url = 'https://api.vultr.com/v2/domains'
    domains_response = requests.get(domains_url, headers=headers)
    domains = domains_response.json()['domains']

    ip_addresses = set()  # Используем множество для автоматического удаления дубликатов

    # Для каждого домена получим записи
    for domain in domains:
        domain_name = domain['domain']
        records_url = f'https://api.vultr.com/v2/domains/{domain_name}/records'
        records_response = requests.get(records_url, headers=headers)
        records = records_response.json()['records']

        # Собираем все A-записи
        for record in records:
            if record['type'] == 'A':
                ip_addresses.add(record['data'])

    return ip_addresses

if __name__ == "__main__":
    try:
        unique_ips = get_dns_records()
        print("Найденные уникальные IP-адреса:")
        for ip in sorted(unique_ips):
            print(ip)
        print(f"\nВсего найдено {len(unique_ips)} уникальных адресов")
    except Exception as e:
        print(f"Ой, что-то пошло не так: {str(e)}")