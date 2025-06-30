#!/usr/bin/env bash

# Проверка доступности хостов из inventory
echo "🔍 Checking hosts availability..."
echo "=================================="

ansible all -i hosts -m ping --one-line | while read line; do
    if [[ $line == *"SUCCESS"* ]]; then
        echo "✅ $line"
    else
        echo "❌ $line"
    fi
done

echo ""
echo "📊 Summary:"
ansible all -i hosts -m ping --one-line | grep -c "SUCCESS" | xargs echo "✅ Available hosts:"
ansible all -i hosts -m ping --one-line | grep -c "UNREACHABLE\|FAILED" | xargs echo "❌ Unavailable hosts:"
echo "=================================="
echo "🔚 Check completed."
# Завершение скрипта
exit 0
# Конец скрипта
# Примечание: Убедитесь, что у вас установлен Ansible и настроен файл inventory (hosts).
