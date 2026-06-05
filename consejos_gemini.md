Tengo un problema con gtk y mi configuración de hyprland. Al parecer gtk priosiza sus reglas sobra las de hyprland. Ahora . Si reinstalo debían sin intornografico . Habilitó los backport . Intalo Hyprland. Se trae GTK de mismo repositorio que lo traería si fuese desde Gnome ?

La respuesta corta es sí. Si haces una instalación de Debian desde cero sin entorno gráfico y luego instalas Hyprland (incluso usando backports), el sistema va a traer exactamente los mismos paquetes de GTK (como libgtk-3-0 y libgtk-4-1) desde los mismos repositorios de Debian. El paquete en sí no cambia.

Sin embargo, tu instinto de hacer una instalación limpia tiene mucho sentido por una razón diferente: el entorno y los demonios en segundo plano, no los paquetes.

¿Por qué GTK "pisa" a Hyprland actualmente?
El problema que estás experimentando rara vez tiene que ver con el paquete de GTK en sí, sino con quién tiene el control de su configuración.

Cuando tienes GNOME (o partes de él) instalado, hay procesos en segundo plano como gnome-settings-daemon, dconf o gsettings que son muy agresivos. Estos demonios se ejecutan y fuerzan sus propias reglas sobre cómo deben verse y comportarse las ventanas GTK (temas, decoraciones del lado del cliente o CSD, cursores, etc.), ignorando o sobreescribiendo las directivas de tu compositor de Wayland.

La ventaja de una instalación mínima (Netinst)
Si reinstalas Debian sin entorno gráfico y construyes tu ecosistema de Hyprland desde cero:

Eliminas intermediarios: No tendrás a los demonios de GNOME ejecutándose en segundo plano y peleando por el control del tema.

Control absoluto: La configuración de GTK dependerá única y exclusivamente de los archivos estándar (~/.config/gtk-3.0/settings.ini y ~/.config/gtk-4.0/settings.ini) o de las variables de entorno que tú definas en tu hyprland.conf.

Sistema más ligero: Solo instalarás las dependencias de GTK que tus aplicaciones necesiten, sin todo el ecosistema de GNOME arrastrándose detrás.

Cómo solucionarlo sin tener que reinstalar (si quieres ahorrar tiempo)
Antes de formatear, puedes intentar quitarle el control a GNOME dentro de tu sesión de Hyprland. Asegúrate de tener esto en tu archivo de configuración de Hyprland:

Forzar las variables de entorno correctas:

Plaintext
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
Centralizar la configuración de GTK: En lugar de dejar que GNOME lo gestione, utiliza una herramienta independiente y nativa para Wayland/wlroots como nwg-look. Esta herramienta edita directamente los archivos .ini y los esquemas de gsettings sin depender de demonios pesados.

Desactivar procesos de GNOME: Revisa que en tus líneas exec-once no se esté lanzando nada relacionado con gnome-settings-daemon o servicios similares.

Si después de intentar esto el sistema sigue sintiéndose "sucio" con las reglas de GNOME interfiriendo, entonces sí, la ruta de la instalación mínima con backports te dará esa base limpia que buscas para que Hyprland y GTK convivan en paz.

Tengo Gnome instalado la verdad por vago por no querer instala gestor de archivos . Tienda de software y cosas que funcionan en Hyprland. Pense que convivir ambos mundos . Probaré los de las variables de entorno . Y de último lo intentare con kde plasma y si no usará solo Hyprland

Es totalmente comprensible. Instalar un entorno completo de base es la táctica clásica para tener resuelto de un plumazo el gestor de archivos, la papelera, el automontaje de pendrives y el gestor de red sin tener que configurarlos uno por uno.

El problema es que GNOME es un ecosistema monolítico; le gusta tener el control absoluto y no comparte bien los juguetes cuando intentas usar un compositor independiente.

Sobre probar KDE Plasma
Ten cuidado con esta ruta. Si instalas KDE Plasma junto a Hyprland, simplemente vas a cambiar de problema.

KDE está construido sobre Qt, mientras que gran parte del ecosistema (y probablemente muchas aplicaciones que usas a diario) están basadas en GTK. Si haces esto, vas a terminar lidiando con demonios diferentes (kded, kwallet) y peleando para que las aplicaciones GTK no se vean fuera de lugar dentro de un sistema dominado por Qt. La convivencia de Hyprland con Plasma puede ser igual de ruidosa o más que con GNOME.

Si decides ir solo con Hyprland
Si las variables de entorno no logran domar a GNOME y decides ir por la ruta de Hyprland puro, no tiene por qué ser un dolor de cabeza ni requerir horas de configuración. Especialmente al usar backports, donde buscas un sistema base muy limpio y moderno, puedes replicar las comodidades de un entorno completo instalando herramientas modulares:

Gestor de archivos: thunar (con los plugins thunar-volman y gvfs para que monte USBs y discos de red automáticamente). Es ligero y respeta muy bien los temas de GTK.

Autenticación (Polkit): lxpolkit o polkit-kde-agent-1. Esto es lo que hace que te salte la ventana pidiendo contraseña cuando una app necesita permisos de administrador.

Gestor de Redes: nm-applet. Te pone el clásico ícono de Wi-Fi en tu barra de estado (como Waybar) para que no tengas que conectarte desde la terminal.

Montaje automático de USBs: udiskie (simplemente lo agregas a las líneas exec-once de tu configuración).

Tienda de software: Si realmente quieres una interfaz gráfica y no usar solo apt, puedes instalar la tienda de GNOME sin el entorno completo ejecutando apt install --no-install-recommends gnome-software.

Prueba primero las variables de entorno y fíjate si logras que el sistema te respete el tema gráfico. Si te terminas hartando de las interferencias, el camino de Hyprland "standalone" es mucho más sencillo de lo que parece una vez que conoces esos 4 o 5 paquetes clave.

¿Quieres la lista exacta de paquetes para un Hyprland puro?

Sí

Si dame la lista. Thunar no es hecha para x11 y nm-applet no es hecha para x11 ?

Es una excelente pregunta y una duda muy lógica cuando uno da el salto a Wayland.

La respuesta rápida es: No, no vas a depender de XWayland para usarlas. Ambas aplicaciones corren 100% nativas en Wayland hoy en día.

Aquí te explico por qué, y luego te paso la lista exacta.

El mito de "las apps de X11"
Es cierto que tanto thunar como nm-applet nacieron en la época donde X11 era el rey absoluto. Sin embargo, ninguna de las dos está programada "directamente" para X11. Ambas están construidas sobre GTK3 (el toolkit gráfico).

GTK3 y GTK4 tienen lo que se llama "backends". Cuando tú ejecutas Thunar en Hyprland, GTK detecta la variable de entorno de Wayland y automáticamente usa el backend de Wayland en lugar del de X11.

Thunar: Se dibujará perfectamente usando Wayland.

nm-applet: Utiliza un protocolo moderno llamado StatusNotifierItem (o AppIndicator). Si usas una barra nativa de Wayland como Waybar, el ícono de red aparecerá allí de forma nativa, sin tocar X11.

La lista de paquetes para un Hyprland puro en Debian
Para mantener tu sistema limpio y evitar que se instalen cientos de dependencias inútiles (juegos, reproductores de música que no quieres, temas de otros entornos), el secreto es usar el parámetro --no-install-recommends en apt.

Aquí tienes la lista dividida por categorías para que sepas exactamente qué hace cada cosa. Puedes instalar todo con un solo comando al final.

1. Archivos y Dispositivos USB
thunar: El gestor de archivos ligero.

thunar-volman: El plugin para que Thunar gestione volúmenes.

gvfs y gvfs-backends: El motor invisible que permite montar pendrives, discos externos y acceder a redes compartidas (SMB/Samba). Sin esto, Thunar es ciego a los USBs.

udiskie: Un demonio ligerísimo que montará tus USB automáticamente en cuanto los conectes.

2. Redes y Bluetooth
network-manager-gnome: Aunque dice "gnome", este es el paquete que contiene nm-applet y la ventana de conexiones. Es el estándar de la industria.

blueman: Un gestor de Bluetooth ligero e independiente (te da el comando blueman-applet para tener el ícono en tu barra).

3. Autenticación y Audio
polkit-kde-agent-1: No te asustes por el "kde". Es solo un cuadrito de diálogo minúsculo y muy estable que salta cuando una app te pide la contraseña de root. (Si prefieres evitar cualquier cosa de KDE, puedes usar lxpolkit).

pavucontrol: El mezclador de audio gráfico. Nativo, simple y respeta GTK.

El Comando de Instalación
Ejecuta esto en tu terminal para instalar la base gráfica sin basura:

Bash
sudo apt install --no-install-recommends thunar thunar-volman gvfs gvfs-backends udiskie network-manager-gnome blueman polkit-kde-agent-1 pavucontrol
¿Cómo integrarlos en Hyprland?
Para que todo esto funcione automáticamente cuando inicies sesión, solo tienes que agregar estas líneas en la sección de inicio de tu archivo hyprland.conf:

Plaintext
# Autenticación (el diálogo de contraseña)
exec-once = /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1

# Montaje automático de USBs
exec-once = udiskie &

# Íconos en la barra (Waybar)
exec-once = nm-applet --indicator &
exec-once = blueman-applet &
Con esta base, tendrás un sistema completamente funcional, moderno, ligero y nativo en Wayland, sin un solo proceso de GNOME peleando por el control de tu tema.

Con respecto a la barra quiero usar eww y ese es el problema con Hyprland y wayland y GTK que no maneja el blue ni transparencias . Y si uso en la configuración de eww ignorezero y blur me rompe el css de la barra

Ah, eww y el blur en Hyprland. Bienvenido al "jefe final" de la personalización en Wayland. Es un problema clásico y muy frustrante, pero tiene solución.

Lo que estás experimentando no es exactamente que GTK priorice sus reglas, sino un conflicto de comunicación entre cómo CSS dibuja los bordes y cómo Hyprland renderiza el desenfoque en la pantalla.

¿Por qué ignorezero "rompe" tu CSS?
eww se dibuja usando un protocolo llamado gtk-layer-shell. Para Hyprland, esa barra es un rectángulo perfecto.

Cuando usas ignorezero, le estás diciendo a Hyprland: "Solo ignora el desenfoque en los píxeles que sean 100% transparentes (alpha = 0)".
El problema es que CSS usa anti-aliasing (suavizado de bordes) para crear las esquinas redondeadas (border-radius) o las sombras (box-shadow). Esos píxeles en el borde no son 0% opacos; son 1%, 2% o 5% opacos para que la curva se vea suave.

Al usar ignorezero, Hyprland intenta aplicarle blur a esos píxeles semi-transparentes de los bordes, lo que resulta en un renderizado horrible: cajas negras alrededor de tus widgets, esquinas cuadradas fantasma, o artefactos visuales que hacen parecer que el CSS se rompió.

La solución: Cambiar ignorezero por ignorealpha
En lugar de usar ignorezero, debes usar ignorealpha con un umbral. Esto le dice a Hyprland: "Ignora el desenfoque en cualquier píxel que tenga menos de X% de opacidad". Esto salva el anti-aliasing de tus esquinas redondeadas.

Paso 1: En tu hyprland.conf
Las reglas para eww no son windowrulev2, son layerrule. Debes apuntar al nombre exacto de tu ventana definido en tu archivo eww.yuck (por ejemplo, si tu ventana se llama bar, el namespace es bar).

Borra tus reglas anteriores de eww y usa estas:

Plaintext
# Activar blur para la barra
layerrule = blur, bar 

# Ignorar el blur en cualquier píxel con menos del 20% de opacidad.
# Esto salva tus bordes redondeados y márgenes transparentes de CSS.
layerrule = ignorealpha 0.2, bar
(Nota: Si en tu eww.yuck tienes (defwindow mibarra ..., entonces la regla debe decir blur, mibarra).

Paso 2: En tu eww.scss
Para que Hyprland pueda hacer su magia por debajo, el fondo del contenedor principal de tu barra en eww debe ser completamente transparente, y le aplicas el color semi-transparente solo al contenedor interno de la barra.

SCSS
// El fondo del nivel más alto debe ser transparente
window {
    background-color: transparent;
    all: unset; // Esto elimina cualquier estilo por defecto oscuro de GTK
}

// A tu barra real le aplicas el color con transparencia (RGBA)
.mi-barra-clase {
    background-color: rgba(30, 30, 46, 0.7); // 70% opaco, el blur hará el resto
    border-radius: 12px;
}
Un detalle importante sobre Eww en Wayland
Asegúrate de que en tu archivo eww.yuck, la definición de la ventana esté usando la sintaxis moderna para Wayland, especificando la propiedad monitor de forma explícita y pidiendo exclusión de zona (para que las ventanas no se superpongan a la barra):

Lisp
(defwindow bar
    :monitor 0
    :geometry (geometry :x "0%"
                        :y "10px"
                        :width "98%"
                        :height "40px"
                        :anchor "top center")
    :stacking "fg"
    :exclusive true ;; Le dice a Hyprland que reserve este espacio
    :windowtype "dock"
  (tus-widgets-aqui))
Con ignorealpha 0.2 en Hyprland y background-color: transparent en la raíz de tu CSS de Eww, deberías conseguir esa barra difuminada y transparente perfecta sin esquinas corruptas.


