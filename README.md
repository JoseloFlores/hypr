# 🚀 Hyprland + Eww para Debian 13 (Trixie)

Este repositorio contiene una configuración (dotfiles) completa y automatizada para transformar una instalación base de **Debian 13 (Trixie)** (se recomienda una instalacion minima) en un entorno de escritorio moderno, rápido y estéticamente pulido basado en **Hyprland** y **Eww**.

![Hyprland](https://img.shields.io/badge/OS-Debian%2013-red?logo=debian)
![Window Manager](https://img.shields.io/badge/WM-Hyprland-blue)
![Status Bar](https://img.shields.io/badge/Bar-Eww-green)

---

## 📸 Screenshots

![Preview 1](preview1.png)
![Preview 2](preview2.png)

---

## 🛠️ Requisitos Previos

1. **Sistema Operativo:** Debian 13 (Trixie) instalado (preferiblemente mínimo sin otro escritorio).
2. **Git:** Para clonar el repositorio.
3. **Fuente Nerd Font:** Se requiere una fuente parcheada (ej. Meslo, JetBrainsMono) para ver los iconos correctamente.
4. **Usuario:** Debes tener permisos de `sudo`.

---

## 🚀 Instalación en un Solo Paso

He diseñado un script inteligente que se encarga de todo: habilitar repositorios, instalar aplicaciones, y compilar la barra de estado.

### 1. Clonar el Repositorio
Abre tu terminal y descarga tus configuraciones:

```bash
git clone https://github.com/JoseloFlores/hypr.git
cd hypr
```

### 2. Ejecutar el Instalador
Simplemente ejecuta el script con permisos de superusuario:

```bash
sudo ./install.sh
```

**¿Qué hace este script por ti?**
- ✅ **Repositorios:** Habilita *Backports* y añade los repositorios oficiales de Hyprland, Rust y Cargo para compilar la barra de eww
- ✅ **Drivers:** Detecta si tienes procesador Intel , AMD y/ Tarjetas NVIDIA y descarga los drivers de video de soporte de aceleración gráfica.
- ✅ **Compilación:** Descarga y compila **Eww** (la barra de estado) desde su código fuente original.
- ✅ **Personalización:** Descarga automáticamente el tema de la barra desde el repo de JoseloFlores/eww.
- ✅ **Portabilidad:** Ajusta todas las rutas internas para que funcionen con TU nombre de usuario.
- ✅ **Apps:** Instala herramientas esenciales (Foot, Thunar, Fuzzel, Swaybg, etc.).

---

## ⌨️ Atajos de Teclado Principales (Guía Rápida)

Una vez reinicies y entres en Hyprland, estos son los comandos que necesitas conocer:

| Atajo | Acción |
| :--- | :--- |
| `Super + Enter` | Abrir Terminal (**Foot**) |
| `Super + C` | Abrir Navegador (**Google Chrome**) |
| `Super + D` | Lanzador de aplicaciones (**Fuzzel**) |
| `Super + X` | Explorador de Archivos (**Thunar**) |
| `Super + Q` | Cerrar ventana activa |
| `Super + L` | Menú de Energía (Apagar/Reiniciar) |
| `Super + Shift + B` | Reiniciar barra Eww y sincronizar colores |
| `Super + 1-9` | Cambiar de escritorio |
| `Print` | Captura de pantalla (Seleccionar área) |

*(La tecla `Super` suele ser la tecla Windows , puedes modificarla a otra como `Alt`)*

---

## 🎨 Personalización y Temas

Este entorno utiliza un sistema de **Sincronización de Colores**:

1.  La fuente de verdad es el archivo `~/.config/eww/eww.scss`.
2.  Al presionar `Super + Shift + B`, el script `foot_sync.sh` lee el tema de Eww y aplica los mismos colores a tu terminal (**Foot**) y al lanzador (**Fuzzel**) automáticamente.

---

## 📁 Estructura de Archivos

*   `~/.config/hypr/`: Configuración principal del gestor de ventanas y scripts de sistema.
*   `~/.config/eww/`: Todo lo relacionado con la barra de estado y los widgets.
*   `~/.config/foot/`: Configuración de la terminal.
*   `~/.config/fuzzel/`: Configuración del lanzador de apps.

---

## ⚠️ Notas Importantes

- **Primer Inicio:** Si al entrar no ves la barra, presiona `Super + Shift + B` para forzar su inicio inicial.
- **Audio/Bluetooth:** Puedes gestionarlos directamente desde los iconos de la barra haciendo clic en ellos.
- **VPN:** El icono de la barra está configurado para mostrarse solo cuando una VPN manual está activa (ignora servicios como Tailscale para evitar desorden).
- Con esto tiene una base funcional para que no empieces de cero a tener  un sistema funcional el cual puedes modificar a tus nnecesidades

---
*Desarrollado con ❤️ para la comunidad de Debian.*
