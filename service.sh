#!/system/bin/sh

MODDIR="/data/adb/modules/s23_series_battery_beta"
CONF="$MODDIR/config.json"

# Esperar a que el almacenamiento esté montado si se ejecuta al arrancar
while [ ! -f "$CONF" ]; do
    sleep 2
done

# --- 1. FORZAR 60HZ / TASA DE REFRESCO (Compatibilidad One UI / Samsung) ---
if grep -q '"force60hz":true' "$CONF"; then
    # Límite de tasa estándar en Android
    settings put system peak_refresh_rate 60.0
    settings put system min_refresh_rate 60.0
    
    # Modos nativos de pantalla de Samsung (0 = Estándar 60Hz, 1 = Adaptativo 120Hz)
    settings put system refresh_rate_mode 0 2>/dev/null
    settings put secure refresh_rate_mode 0 2>/dev/null
    
    # Notificación a SurfaceFlinger para forzar el frame rate máximo
    service call SurfaceFlinger 1035 i32 60 2>/dev/null
else
    # Restablecer a tasa adaptativa (hasta 120Hz)
    settings put system peak_refresh_rate 120.0
    settings put system min_refresh_rate 24.0
    
    # Restablecer modo adaptativo en One UI
    settings put system refresh_rate_mode 1 2>/dev/null
    settings put secure refresh_rate_mode 1 2>/dev/null
fi

# --- 2. SUEÑO PROFUNDO (Deep Doze) ---
if grep -q '"doze":true' "$CONF"; then
    # Agresividad de reposo en pantalla apagada
    settings put global device_idle_constants "light_after_inactive_to=30000,light_pre_idle_to=30000,light_idle_to=60000,light_idle_factor=2.0,light_max_idle_to=300000,deep_inactive_to=60000,deep_pre_idle_to=30000,deep_idle_to=600000,deep_max_idle_to=1800000"
    dumpsys deviceidle step >/dev/null 2>&1
else
    # Restaurar parámetros por defecto de Doze
    settings delete global device_idle_constants 2>/dev/null
fi

# --- 3. AHORRO GPU (Governor de Adreno) ---
if grep -q '"gpu_save":true' "$CONF"; then
    echo "powersave" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
else
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
fi

# --- 4. DORMIR GOOGLE PLAY SERVICES (GMS Nap) ---
if grep -q '"gms_nap":true' "$CONF"; then
    cmd deviceidle restrict-background com.google.android.gms 2>/dev/null
else
    cmd deviceidle unrestrict-background com.google.android.gms 2>/dev/null
fi

# --- 5. MATAR SINCRONIZACIÓN AUTOMÁTICA ---
if grep -q '"kill_sync":true' "$CONF"; then
    settings put global auto_sync 0
else
    settings put global auto_sync 1
fi

# --- 6. REGULADOR Y TWEAKS CPU / SNAPDRAGON ---
if grep -q '"governor":true' "$CONF"; then
    # Desactivar depuración de interrupciones para reducir wakelocks del kernel
    echo "0" > /sys/module/msm_show_resume_irq/parameters/debug_mask 2>/dev/null
    echo "0" > /proc/sys/kernel/sched_schedstats 2>/dev/null
fi

exit 0