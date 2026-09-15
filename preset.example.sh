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
# SDDM opcional: OFF por defecto (greetd es el login del repo). ON solo instala sddm sin tema.
INSTALL_SDDM="OFF"
