#!/system/bin/sh
until [ "$(getprop sys.boot_completed)" -eq 1 ]; do sleep 3; done

# Lista blanca para evitar retrasos en mensajería push
cmd deviceidle whitelist +com.whatsapp
cmd deviceidle whitelist +com.telegram.messenger
cmd deviceidle whitelist +com.google.android.gms
cmd deviceidle whitelist +com.android.vending

# Ajuste dinámico de memoria RAM basado en la capacidad del dispositivo
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')

if [ "$TOTAL_RAM" -gt 9000 ]; then
    # Ajustes para variantes de 12GB (S23 Ultra) - Gestión de caché más holgada
    echo "80" > /proc/sys/vm/vfs_cache_pressure
    echo "15" > /proc/sys/vm/swappiness
else
    # Ajustes para variantes de 8GB (S23 Base / S23+) - Conservar RAM física
    echo "100" > /proc/sys/vm/vfs_cache_pressure
    echo "10" > /proc/sys/vm/swappiness
fi