#!/bin/bash

# Detectar VPN activa (priorizando tipos vpn/wireguard e ignorando tailscale)
VPN_NAME=$(LANG=C nmcli -t -f NAME,TYPE,STATE connection show --active | grep -E ':vpn:|:wireguard:' | grep 'activated' | head -n1 | cut -d: -f1)

if [ -z "$VPN_NAME" ]; then
    VPN_NAME=$(LANG=C nmcli -t -f NAME,TYPE,STATE connection show --active | grep ':tun:' | grep -v 'tailscale' | grep 'activated' | head -n1 | cut -d: -f1)
fi

# Detectar WiFi
WIFI_INFO=$(LANG=C nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes')
WIFI_SSID=$(echo "$WIFI_INFO" | cut -d: -f2)
WIFI_SIGNAL=$(echo "$WIFI_INFO" | cut -d: -f3)

# Detectar Ethernet
ETH_ACTIVE=$(LANG=C nmcli -t -f TYPE,STATE connection show --active | grep 'ethernet' | grep 'activated')

if [ -n "$VPN_NAME" ]; then
    ICON="󰖂"
    CLASS="vpn"
    TEXT="$ICON"
    TOOLTIP="VPN: $VPN_NAME"
    if [ -n "$WIFI_SSID" ]; then
        TOOLTIP="$TOOLTIP\\nWiFi: $WIFI_SSID ($WIFI_SIGNAL%)"
    fi
elif [ -n "$ETH_ACTIVE" ]; then
    ICON="󰈀"
    CLASS="ethernet"
    TEXT="$ICON"
    TOOLTIP="Ethernet conectado"
elif [ -n "$WIFI_SSID" ]; then
    if [ "$WIFI_SIGNAL" -lt 25 ]; then
        ICON="󰤟"
    elif [ "$WIFI_SIGNAL" -lt 50 ]; then
        ICON="󰤢"
    elif [ "$WIFI_SIGNAL" -lt 75 ]; then
        ICON="󰤥"
    else
        ICON="󰤨"
    fi
    CLASS="wifi"
    TEXT="$ICON"
    TOOLTIP="WiFi: $WIFI_SSID ($WIFI_SIGNAL%)"
else
    ICON="󰤭"
    CLASS="disconnected"
    TEXT="$ICON"
    TOOLTIP="Desconectado"
fi

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
