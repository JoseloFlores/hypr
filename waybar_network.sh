#!/bin/bash

# Detectar VPN activa (priorizando tipos vpn/wireguard e ignorando tailscale)
VPN_NAME=$(LANG=C nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep -E ':vpn:|:wireguard:' | grep 'activated' | head -n1 | cut -d: -f1)

if [ -z "$VPN_NAME" ]; then
    VPN_NAME=$(LANG=C nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ':tun:' | grep -v 'tailscale' | grep 'activated' | head -n1 | cut -d: -f1)
fi

# Detectar WiFi via NetworkManager
WIFI_INFO=$(LANG=C nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes')
WIFI_SSID=$(echo "$WIFI_INFO" | cut -d: -f2)
WIFI_SIGNAL=$(echo "$WIFI_INFO" | cut -d: -f3)

# Fallback si NM no gestiona wifi (unmanaged -> dhcpcd/ifupdown) pero ip está UP
if [ -z "$WIFI_SSID" ]; then
    WIFI_IF=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E "^wlp|^wlan" | head -n1)
    # verificar que esté UP
    if [ -n "$WIFI_IF" ] && ip link show "$WIFI_IF" 2>/dev/null | grep -q "UP" && ip -4 addr show "$WIFI_IF" 2>/dev/null | grep -q "inet "; then
        # Intentar obtener SSID real
        if command -v iwgetid &>/dev/null; then
            WIFI_SSID=$(iwgetid -r 2>/dev/null)
        fi
        if [ -z "$WIFI_SSID" ] && command -v iw &>/dev/null; then
            WIFI_SSID=$(iw dev "$WIFI_IF" link 2>/dev/null | grep SSID | sed 's/.*SSID: //')
        fi
        if [ -z "$WIFI_SSID" ]; then
            WIFI_SSID="Conectado ($WIFI_IF)"
        fi
        # Señal via /proc/net/wireless (link 0-70 -> 0-100%)
        WIFI_SIGNAL=$(awk -v iface="$WIFI_IF:" '$1==iface {print int($3*100/70)}' /proc/net/wireless 2>/dev/null)
        [ -z "$WIFI_SIGNAL" ] && WIFI_SIGNAL=65
        # Marcar como unmanaged para tooltip
        WIFI_UNMANAGED=1
    fi
fi

# Detectar Ethernet
ETH_ACTIVE=$(LANG=C nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | grep 'ethernet' | grep 'activated')
# Fallback eth via ip si NM no lo ve (filtrar solo nombre iface, no link/ether)
if [ -z "$ETH_ACTIVE" ]; then
    ETH_IF=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E "^enp|^ens|^eth" | head -n1)
    if [ -n "$ETH_IF" ] && ip link show "$ETH_IF" 2>/dev/null | grep -q "UP" && ip -4 addr show "$ETH_IF" 2>/dev/null | grep -q "inet "; then
        ETH_ACTIVE="eth:$ETH_IF"
    fi
fi

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
    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_UNMANAGED" ]; then
        TOOLTIP="$TOOLTIP\\nWiFi fallback: $WIFI_SSID"
    fi
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
    if [ -n "$WIFI_UNMANAGED" ]; then
        TOOLTIP="$TOOLTIP\\n⚠ Gestionado por dhcpcd (no NM) - click para nmtui (requiere migrar a NM)"
    fi
else
    ICON="󰤭"
    CLASS="disconnected"
    TEXT="$ICON"
    # Detectar si está unmanaged
    if nmcli dev status 2>/dev/null | grep -q "unmanaged"; then
        TOOLTIP="Desconectado (WiFi unmanaged - migrar a NetworkManager)"
    else
        TOOLTIP="Desconectado"
    fi
fi

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
