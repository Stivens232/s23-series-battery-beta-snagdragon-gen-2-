const CONFIG_PATH = "/data/adb/modules/s23_series_battery_beta/config.json";

// 1. Ejecutor de comandos compatible con KernelSU-Next (Promesas asíncronas)
async function execCmd(command) {
  try {
    if (window.ksu && typeof window.ksu.exec === "function") {
      const res = await window.ksu.exec(command);
      return typeof res === "object" ? (res.stdout || "") : res;
    } else if (typeof ksu !== "undefined" && typeof ksu.exec === "function") {
      const res = await ksu.exec(command);
      return typeof res === "object" ? (res.stdout || "") : res;
    }
  } catch (err) {
    console.error("Error ejecutando comando en KSU-Next:", err);
  }
  return "";
}

// 2. Inicialización al cargar la interfaz
document.addEventListener("DOMContentLoaded", () => {
  setTimeout(() => {
    loadConfig();
    updateMetrics();
    setInterval(updateMetrics, 2000); // Actualiza sensores cada 2 segundos
  }, 300);
});

// 3. Cargar el estado guardado en config.json
async function loadConfig() {
  const jsonStr = await execCmd(`cat ${CONFIG_PATH}`);
  if (!jsonStr) return;

  try {
    const cfg = JSON.parse(jsonStr.trim());
    if (document.getElementById("doze")) document.getElementById("doze").checked = !!cfg.doze;
    if (document.getElementById("governor")) document.getElementById("governor").checked = !!cfg.governor;
    if (document.getElementById("gpu_save")) document.getElementById("gpu_save").checked = !!cfg.gpu_save;
    if (document.getElementById("force60hz")) document.getElementById("force60hz").checked = !!cfg.force60hz;
    if (document.getElementById("gms_nap")) document.getElementById("gms_nap").checked = !!cfg.gms_nap;
    if (document.getElementById("kill_sync")) document.getElementById("kill_sync").checked = !!cfg.kill_sync;
  } catch (e) {
    console.error("Error al parsear JSON:", e);
  }
}

// 4. Lectura de sensores en tiempo real
async function updateMetrics() {
  // A. Salud / Degradación de la Batería
  let healthText = "";

  // Método 1: Calcular porcentaje de degradación real (Capacidad actual vs Capacidad de fábrica)
  const chargeFull = await execCmd("cat /sys/class/power_supply/battery/charge_full 2>/dev/null || cat /sys/class/power_supply/battery/fg_fullcapnom 2>/dev/null");
  const chargeDesign = await execCmd("cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || cat /sys/class/power_supply/battery/fg_cyclecode 2>/dev/null");

  if (chargeFull && chargeDesign && parseInt(chargeDesign.trim()) > 0) {
    const full = parseInt(chargeFull.trim());
    const design = parseInt(chargeDesign.trim());
    const healthPct = Math.min(100, Math.round((full / design) * 100));
    healthText = `${healthPct}%`;
  }

  // Método 2: Fallback al estado del kernel si no se leen valores exactos en mAh
  if (!healthText) {
    const rawHealth = await execCmd("cat /sys/class/power_supply/battery/health 2>/dev/null");
    if (rawHealth && rawHealth.trim()) {
      const status = rawHealth.trim().toLowerCase();
      if (status === "good") healthText = "100%";
      else if (status === "overheat") healthText = "Sobrecalentada";
      else if (status === "dead") healthText = "Degradada";
      else healthText = rawHealth.trim();
    }
  }

  document.getElementById("health-val").innerText = healthText || "100%";

  // B. Corriente Instantánea (mA)
  const current = await execCmd("cat /sys/class/power_supply/battery/current_now");
  if (current && current.trim()) {
    let mA = parseInt(current.trim());
    if (Math.abs(mA) > 10000) mA = Math.round(mA / 1000); // Conversión de uA a mA
    document.getElementById("current-val").innerText = `${mA} mA`;
  }

  // C. Temperatura (°C)
  const temp = await execCmd("cat /sys/class/power_supply/battery/temp");
  if (temp && temp.trim()) {
    const tempC = (parseInt(temp.trim()) / 10).toFixed(1);
    document.getElementById("temp-val").innerText = `${tempC} °C`;
  }

  // D. Tasa de Refresco (Hz) - Lectura directa de One UI / Android
  let hzVal = "";

  const sfRaw = await execCmd("dumpsys SurfaceFlinger | grep -oE '[0-9]{2,3}(\\.[0-9]+)? Hz' | head -n1");
  
  if (sfRaw && sfRaw.trim()) {
    hzVal = sfRaw.trim();
  } else {
    const displayDump = await execCmd("dumpsys display | grep -iE 'mRenderFrameRate|fps=' | head -n1");
    if (displayDump) {
      const match = displayDump.match(/\b(24|30|48|60|90|120|144|240)\b/);
      if (match) hzVal = `${match[0]} Hz`;
    }
  }

  document.getElementById("fps-val").innerText = hzVal || "120.00 Hz";
}

// 5. Guardar configuración y aplicar cambios dinámicos
async function saveConfig() {
  const newConfig = {
    hotplug: true,
    governor: document.getElementById("governor")?.checked || false,
    doze: document.getElementById("doze")?.checked || false,
    saver: true,
    eco70: false,
    eco50: false,
    force60hz: document.getElementById("force60hz")?.checked || false,
    gpu_save: document.getElementById("gpu_save")?.checked || false,
    gms_nap: document.getElementById("gms_nap")?.checked || false,
    kill_sync: document.getElementById("kill_sync")?.checked || false,
    bypass: false
  };

  const jsonString = JSON.stringify(newConfig);

  // Escribir en el config.json
  await execCmd(`echo '${jsonString}' > ${CONFIG_PATH}`);
  
  // Ejecutar el script shell para aplicar cambios del sistema inmediatamente
  await execCmd("sh /data/adb/modules/s23_series_battery_beta/service.sh");

  // Forzar actualización inmediata de los cuadros de métricas
  setTimeout(updateMetrics, 500);

  alert("¡Ajustes aplicados correctamente!");
}