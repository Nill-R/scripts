#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

echo "🔍 Checking hosts availability..."
echo "=================================="

ansible all -i hosts -m ping --one-line | while read -r line; do
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

exit 0

