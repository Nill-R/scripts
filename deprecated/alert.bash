#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

# this is example not for production use

client='тут ключ из вывода команды wg show wg0'

# Время последней активности
l_date=$(wg show wg0 latest-handshakes | grep "$client" | awk '{print $2}')

# Не паниковать если интерфейс перезагрузился
if [[ l_date -eq 0 ]]; then exit; fi

# Текущая дата
c_date=$(date +%s)

# Разница в секундах
date=$((c_date-l_date))

if [[ $date -ge 86400 ]]; then echo Alarm!!!; fi
