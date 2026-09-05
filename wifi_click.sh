#!/bin/bash
# Helper para click en módulo WiFi de Waybar
# Si NM está unmanaged (dhcpcd), avisa y ofrece diagnóstico; si está managed, abre nmtui

if nmcli dev status 2>/dev/null | grep -q "unmanaged"; then
    # Intentar mostrar estado actual y ofrecer migrar
    WIFI_IF=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E "^wlp|^wlan" | head -n1)
    SSID_FALLBACK=$(iwgetid -r 2>/dev/null || echo "desconocido")
    MSG="WiFi está en modo unmanaged (gestionado por dhcpcd/ifupdown, no por NetworkManager).\n\nInterfaz: $WIFI_IF\nSSID: $SSID_FALLBACK\nIP: $(ip -4 addr show "$WIFI_IF" 2>/dev/null | grep inet | awk '{print $2}' | head -n1)\n\nPara ver redes disponibles necesitas migrar a NetworkManager.\n¿Abrir nmtui igualmente? (mostrará lista vacía hasta migrar)"
    # Usar foot para mostrar info y lanzar nmtui si el usuario quiere
    foot -e bash -c "
        echo '=== WiFi unmanaged ==='
        echo
        nmcli dev status
        echo
        echo 'IP actual:'
        ip -4 addr show $WIFI_IF 2>/dev/null | grep inet
        echo
        echo 'Redes visibles (nmcli, requiere NM managed):'
        nmcli dev wifi list --rescan yes 2>&1 | head -n 20
        echo
        echo 'Para migrar a NetworkManager, ejecuta en terminal:'
        echo '  sudo sed -i \"s/managed=false/managed=true/\" /etc/NetworkManager/NetworkManager.conf'
        echo '  echo -e \"[keyfile]\\nunmanaged-devices=none\" | sudo tee /etc/NetworkManager/conf.d/10-globally-managed-devices.conf'
        echo '  sudo bash -c \"cat > /etc/network/interfaces <<EOF\n\nauto lo\niface lo inet loopback\nEOF\"'
        echo '  sudo systemctl restart NetworkManager'
        echo
        read -p 'Pulsa Enter para abrir nmtui (o Ctrl+C para salir)...'
        nmtui
    " &
else
    # NM gestiona wifi, abrir nmtui normal
    foot -e nmtui &
fi
