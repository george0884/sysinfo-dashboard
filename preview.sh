#!/bin/bash

# 1. IMPORTAR EL OTRO SCRIPT (Sin ejecutarlo, solo cargando sus variables)
# Suponiendo que sysinfo.sh guarda los datos en variables como $cpu, $ram, etc.
if [ -f "./sysinfo.sh" ]; then
    . ./sysinfo.sh > /dev/null 2>&1 
fi

# 2. DEFINICIÓN DE COLORES
AZUL='\033[1;34m'
BLANCO='\033[1;37m'
RESET='\033[0m'

# 3. LA LÍNEA QUE HACE EL TRABAJO (Descripción primero y alineada)
mostrar() {
    printf "${AZUL}%-16s${RESET} ${BLANCO}%s${RESET}\n" "$1" "$2"
}

# 4. PRESENTACIÓN DE LOS DATOS
echo -e "${AZUL}System Information:${RESET}"
echo "------------------------------------------"

# Usamos las variables que ya existen en tu sysinfo.sh
# Ajustá los nombres de las variables ($modelo_cpu, $mem_usada, etc.) 
# a los que vos estés usando en el otro archivo.

mostrar "Kernel:" "$(uname -r)"
mostrar "Uptime:" "$(uptime -p | sed 's/up //')"

# Ejemplo si en sysinfo.sh tenés una variable llamada CPU_MODEL:
mostrar "CPU Model:" "$CPU_MODEL"

# Ejemplo si tenés una para la memoria:
mostrar "Memory Usage:" "$MEM_TOTAL"

echo "------------------------------------------"
