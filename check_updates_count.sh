#!/bin/bash
if command -v apt &> /dev/null; then
    echo $(LC_ALL=C apt list --upgradable 2>/dev/null | grep -c "upgradable")
elif command -v checkupdates &> /dev/null; then
    checkupdates | wc -l
else
    echo 0
fi
