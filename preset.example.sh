# =============================================================================
#  preset.example.sh — Preset no-interactivo para install.sh
#  Uso: sudo ./install.sh --preset preset.example.sh
#       ./install.sh --dry-run --preset preset.minimal.sh
#  Valores: ON | OFF | auto (solo NVIDIA_MODE)
# =============================================================================

# --- Módulos (ON salta, OFF omite) ---
REPOS="ON"
DRIVERS="ON"
BASE="ON"
HYPR="ON"
FONTS="ON"
GREETD="ON"
DOTS="ON"
NOCTALIA="ON"
# Plugins Noctalia del repo (region-recorder + parche wf-recorder). OFF = solo base.
NOCTALIA_PLUGINS="ON"
PAM="ON"
SERVICES="ON"
GRUB="ON"

# --- Opciones finas ---
# auto = detecta por lspci (comportamiento original) | ON = fuerza nvidia | OFF = nunca nvidia
NVIDIA_MODE="auto"
INSTALL_THUNAR="ON"
INSTALL_MEDIA="ON"
INSTALL_INPUT_GROUP="ON"
INSTALL_GRUB_THEME="ON"
# Navegador usable en netinst limpia (firefox-esr Debian). Chrome/spotify van post-setup manual.
INSTALL_FIREFOX="ON"
# Thunderbird opcional (OFF = no autostart ni binds; hyprland.conf lo trae comentado).
INSTALL_THUNDERBIRD="OFF"
# Wallpapers: se descargan en install (no versionados). Vacío = solo semilla local si existe.
WALLPAPER_URL=""
# Vacío = default ~/Imágenes/wallpapers/wallpaper del usuario real (no usar $HOME: bajo sudo es /root).
WALLPAPER_DIR=""
