#!/bin/bash

if command -v apt &> /dev/null; then
    count=$(LC_ALL=C apt list --upgradable 2>/dev/null | grep -c "upgradable")
elif command -v checkupdates &> /dev/null; then
    count=$(checkupdates | wc -l)
else
    count=0
fi

if [ "$count" -gt 0 ]; then
    echo "{\"text\": \"󰚰 $count\", \"class\": \"pending\"}"
else
    echo ""
fi
