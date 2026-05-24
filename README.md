# Hyprland Dotfiles - Debian 13 Trixie

Este repositorio contiene la configuración optimizada para Hyprland en Debian 13, utilizando **Waybar** como barra principal de estado.

##  Características Principales

-   **Panel Superior (Waybar):** Configuración modular con temas de color a eleccion.
    - **Espacios de Trabajo:** Indicadores dinámicos mediante iconos de ventanas.
        - **Red Unificada:** Módulo inteligente que alterna entre WiFi (con niveles de señal) y VPN de forma automática, ignorando servicios de fondo como Tailscale.
        - **Quick Settings:** Control de volumen (modernizado con Nerd Fonts), red (nmtui) y bluetooth (minimalista con iconos de estado y nombres en tooltip).
        - **Batería:** Iconos estándar mejorados para mayor compatibilidad.
        - **Media Control (MPRIS):** Muestra canción actual y permite control básico (se oculta automáticamente si no hay contenido).
        - **Power Menu Drawer:** Menú expansible en la barra para Apagar, Reiniciar, Bloquear y Salir.
        - **Gestión de Actualizaciones:** Indicador de paquetes pendientes para APT.
-   **Bloqueo de Pantalla:** Configuración de `hyprlock` con fondo difuminado y reloj minimalista.
-   **Idle Management:** `hypridle` configurado para ahorrar energía y bloquear automáticamente.
-   **Estética:** Tema Tokyo Night coherente en Waybar, Wofi y terminal (foot).

## ⌨️ Atajos de Teclado Relevantes

| Atajo | Acción |
| :--- | :--- |
| `Super + Return` | Abrir Terminal (foot) |
| `Super + D` | Lanzador de aplicaciones (Wofi) |
| `Super + Q` | Cerrar Ventana |
| `Super + C` | Abrir Navegador (Chrome) |
| `Super + Z` | Abrir Spotify |
| `Super + L` | Menú de Apagado (Wofi) |
| `Super + Shift + B` | Recargar Waybar |
| `Print` | Captura de pantalla (Área) |

## 🛠️ Estructura de Archivos

-   `hyprland.conf`: Configuración principal de Hyprland (monitores, binds, reglas).
-   `waybar/`: Configuración y estilos de la barra superior.
-   `hyprlock.conf` / `hypridle.conf`: Bloqueo y gestión de inactividad.
-   `check_updates.sh`: Consulta actualizaciones pendientes.
-   `confirm_power.sh`: Diálogo de confirmación para acciones de energía.
-   `power_menu.sh`: Menú de apagado interactivo vía Wofi.
-   `wall.jpeg` / `wall2.jpg`: Fondos de pantalla utilizados.

## 🔧 Instalación

El script `install.sh` automatiza la instalación de dependencias en Arch, Debian y Fedora, y copia los archivos a `~/.config/hypr`.

```bash
chmod +x install.sh
./install.sh
```
