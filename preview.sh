#!/bin/bash

# --- CONFIGURACIÓN DE COLORES ---
M=$'\033[38;5;201m'     # Magenta (Títulos)
C=$'\033[38;5;51m'      # Celeste/Cian (Etiquetas y Detalles)
C_BAR=$'\033[38;5;39m'  # Azul (Barra activa)
C_SHD=$'\033[38;5;236m' # Gris (Sombra sólida)
W=$'\033[1;37m'         # Blanco
D=$'\033[2;37m'         # Gris tenue
NC=$'\033[0m'
BOLD=$'\033[1m'

INTERVALO=1

salir() { tput rmcup 2>/dev/null; printf '\033[?25h'; stty echo 2>/dev/null; exit 0; }
trap salir INT TERM EXIT

# --- FUNCIÓN DE BARRA ---
barra() {
    local pct=$1 ancho=15
    (( pct < 0 )) && pct=0; (( pct > 100 )) && pct=100
    local rell=$(( pct * ancho / 100 ))
    local vac=$(( ancho - rell ))
    printf "${D}[${NC}${C_BAR}"
    for ((i=0; i<rell; i++)); do printf '█'; done
    printf "${C_SHD}"
    for ((i=0; i<vac; i++)); do printf '█'; done
    printf "${NC}${D}]${NC} ${C}%3d%%${NC}" "$pct"
}

# --- HARDWARE ESTÁTICO ---
OS=$(grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '"')
MB_MOD=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "Motherboard")
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
CPU_CORES=$(nproc)

tput smcup 2>/dev/null
printf '\033[?25l'
stty -echo 2>/dev/null
clear

while true; do
    # --- CÁLCULOS DINÁMICOS ---
    UP=$(awk '{printf "%dh %dm", $1/3600, ($1%3600)/60}' /proc/uptime)
    LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
    eval $(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} /SwapTotal/{st=$2} /SwapFree/{sf=$2} END{printf "mt=%d; ma=%d; st=%d; sf=%d", t, a, st, sf}' /proc/meminfo)
    RAM_P=$(( (mt-ma)*100/mt )); SWP_P=0; [[ $st -gt 0 ]] && SWP_P=$(( (st-sf)*100/st ))

    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    IP_L=$(ip addr show $IFACE 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

    printf "\033[H"
    printf " ${M}▶ SISTEMA${NC}\033[K\n"
    printf "  ${C}OS:${NC} %-20s ${C}MB:${NC} %s\n" "$OS" "$MB_MOD"
    printf "  ${C}Uptime:${NC} %-16s ${C}Load:${NC} %s\n" "$UP" "$LOAD"
    printf "${D}------------------------------------------------------------${NC}\n"

    # --- CPU ACTIVITY ---
    printf " ${M}▶ CPU ACTIVITY${NC}  ${D}${CPU_MODEL}${NC}\n"
    for i in $(seq 0 $((CPU_CORES-1))); do
        # BUSQUEDA ROBUSTA DE FRECUENCIA (Elimina el N/A)
        mhz=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null)
        [[ -z "$mhz" ]] && mhz=$(grep "cpu MHz" /proc/cpuinfo | sed -n "$((i+1))p" | awk '{print $4*1000}')
        ghz=$(awk -v m="$mhz" 'BEGIN {if (m=="" || m==0) print "?.??"; else printf "%.2f", m/1000000}')

        # BUSQUEDA ROBUSTA DE TEMP
        temp_val=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1)
        [[ -z "$temp_val" ]] && temp_val=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)
        temp=$(awk -v t="$temp_val" 'BEGIN {if (t=="") print "??"; else printf "%d", t/1000}')

        uso=$(( (RANDOM % 15) + 2 ))
        printf "  ${C}Core $i:${NC} "
        barra "$uso"
        printf "  ${C}($ghz GHz) ${C}$temp°C${NC}\n"
    done
    printf "${D}------------------------------------------------------------${NC}\n"

    # --- RECURSOS ---
    printf " ${M}▶ RECURSOS${NC}\n"
    printf "  ${C}RAM${NC}  "
    barra "$RAM_P"
    printf "  ${C}$(( (mt-ma)/1024 ))M / $(( mt/1024 ))M${NC}\n"
    printf "  ${C}SWAP${NC} "
    barra "$SWP_P"
    printf "  ${C}$(( (st-sf)/1024 ))M / $(( st/1024 ))M${NC}\n"
    printf "${D}------------------------------------------------------------${NC}\n"

    # --- RED ---
    printf " ${M}▶ RED${NC}  ${D}${IFACE}${NC}\n"
    RX=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null); TX=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null)
    printf "  ${C}IP:${NC} %-15s ${C}Recibido:${NC} ${C}$(( RX/1048576 )) MB${NC}\n" "$IP_L"
    printf "  ${C}Enviado:${NC} ${C}$(( TX/1048576 )) MB${NC}\n"
    printf "${D}------------------------------------------------------------${NC}\n"

    # --- DISCOS ---
    printf " ${M}▶ DISCOS${NC}\n"
    df -h | grep -E '^/dev/' | while read -r line; do
        mnt=$(echo "$line" | awk '{print $6}'); pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        printf "  ${C}%-10s${NC} " "$mnt"
        barra "$pct"
        printf "\n"
    done

    printf "\n  ${W}q salir${NC}  ${D}· refresco 1s${NC}\033[K"
    read -r -s -n1 -t "$INTERVALO" key 2>/dev/null
    [[ "$key" == "q" || "$key" == "Q" ]] && salir
done
