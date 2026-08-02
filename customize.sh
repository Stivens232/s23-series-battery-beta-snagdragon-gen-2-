#!/system/bin/sh

ui_print ""
ui_print "S23 Series - Battery beta (Snapdragon Gen 2)"
ui_print "────────────────────────────────"

# 1. VERIFICACIÓN DE LA PLATAFORMA (Snapdragon 8 Gen 2)
PLATFORM=$(getprop ro.board.platform)

if [ "$PLATFORM" != "kalama" ]; then
    ui_print "ERROR: Dispositivo incompatible."
    ui_print "• Detectado: $PLATFORM"
    ui_print "• Requerido: kalama (Snapdragon 8 Gen 2)"
    ui_print ""
    ui_print "La instalación se ha cancelado para evitar daños."
    abort
else
    MODELO=$(getprop ro.product.model)
    ui_print "Procesador compatible detectado ($PLATFORM)"
    ui_print "• Modelo: $MODELO"
fi
# ----------------------------------------

# 2. ENTORNO KERNELSU Y PERMISOS
ui_print "• Entorno: KernelSU"
ui_print "• Colocando archivos y asignando permisos..."

# Permisos para scripts ejecutables y carpetas de servicio
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm_recursive "$MODPATH/service.d" 0 0 0755 0755

# Permisos para Action Script (si existe)
if [ -f "$MODPATH/action.sh" ]; then
    set_perm "$MODPATH/action.sh" 0 0 0755
fi

# Permisos para la WebUI de KernelSU
if [ -d "$MODPATH/webroot" ]; then
    set_perm_recursive "$MODPATH/webroot" 0 0 0755 0755
fi

# Binarios en /system/bin (OverlayFS de KSU)
if [ -f "$MODPATH/system/bin/dipslip" ]; then
    set_perm "$MODPATH/system/bin/dipslip" 0 0 0755
fi

if [ -f "$MODPATH/system/bin/bypass_wrapper.sh" ]; then
    set_perm "$MODPATH/system/bin/bypass_wrapper.sh" 0 0 0755
fi

if [ -d "$MODPATH/system/libexec/encore_bypass" ]; then
    ui_print "• Configurando binarios..."
    set_perm_recursive "$MODPATH/system/libexec/encore_bypass" 0 0 0755 0755
fi

# 3. RESPALDO Y CREACIÓN DE CONFIGURACIÓN (.json)
MODULE_ID=$(grep -E '^id=' "$MODPATH/module.prop" | cut -d= -f2)
LIVE_CONFIG="/data/adb/modules/${MODULE_ID}/config.json"
TEMP_CONFIG="$MODPATH/config.json"

if [ -f "$LIVE_CONFIG" ]; then
    ui_print "• Configuración previa detectada."
    ui_print "  ↳ Restaurando tus ajustes..."
    cp -f "$LIVE_CONFIG" "$TEMP_CONFIG"
else
    ui_print "• Instalación limpia."
    ui_print "  ↳ Creando config por defecto..."
    echo '{"hotplug":true,"governor":true,"doze":true,"saver":true,"eco70":false,"eco50":false,"force60hz":false,"gpu_save":false,"gms_nap":false,"kill_sync":false,"bypass":false}' > "$TEMP_CONFIG"
fi

# Permisos para el archivo de configuración (Lectura y escritura para la WebUI)
set_perm "$TEMP_CONFIG" 0 0 0666

ui_print "────────────────────────────────"
ui_print "• Instalación completa."
ui_print "• Abre el administrador de KernelSU para acceder a la WebUI."
ui_print "• Reinicia el dispositivo para aplicar los cambios iniciales."