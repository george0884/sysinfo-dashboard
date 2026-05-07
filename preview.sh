#!/bin/bash
# =============================================================================
#  sysinfo.sh — Dashboard tiempo real | Termux/Android + Linux
#  Versión Optimizada: Cores individuales + Memoria en GB + Temperatura
# =============================================================================

# Colores
R=$'\033[0;31m'
G=$'\033[0;32m'
Y=$'\033[0;33m'
M=$'\033[0;35m'
C=$'\033[0;36m'
W=$'\033[1;37m'
D=$'\033[2;37m'
NC=$'\033[0m'
BOLD=$'\033[1m'
HIDE=$'\033[?25l'
SHOW=$'\033[?25h'

INTERVALO=2

# ── Salir limpio ──────────────────────────────────────────────────────────────
salir() {
    tput rmcup 2>/dev/null
    printf '%s\n' "$SHOW"
    stty echo 2>/dev/null
    echo "  Dashboard cerrado."
    exit 0
}
trap salir INT TERM EXIT

# ── Datos estáticos ───────────────────────────────────────────────────────────
OS=$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
[[ -z "$OS" ]] && OS="$(uname -o 2>/dev/null || uname -s)"
KERNEL=$(uname -r)
HOST=$(hostname 2>/dev/null || echo "localhost")
USER_NAME=$(whoami 2>/dev/null || echo "${USER:-?}")
CPU_MODEL=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//')
[[ -z "$CPU_MODEL" ]] && CPU_MODEL="$(uname -m)"

# ── Funciones de Interfaz ──────────────────────────────────────────────────────
barra() {
    local pct=$1 ancho=$2
    (( pct < 0   )) && pct=0
    (( pct > 100 )) && pct=100
    local relleno=$(( pct * ancho / 100 ))
    local vacio=$(( ancho - relleno ))
    local color
    if   (( pct >= 90 )); then color=$R
    elif (( pct >= 70 )); then color=$Y
    else                       color=$G
    fi
    printf '%s[%s%s' "$D" "$NC" "$color"
    local i; for (( i=0; i<relleno; i++ )); do printf '█'; done
    printf '%s' "$D"
    for (( i=0; i<vacio;   i++ )); do printf '░'; done
    printf '%s]%s' "$D" "$NC"
}

div() {
    printf '%s' "$D"
    local i; for (( i=0; i<COLS && i<70; i++ )); do printf '─'; done
    printf '%s\n' "$NC"
}

campo() {
    printf '  %s%-16s%s %s\n' "$C" "$1" "$NC" "$2"
}

fila_barra() {
    local label="$1" pct=$2 extra="$3"
    printf '  %s%-16s%s ' "$C" "$label" "$NC"
    barra "$pct" "$BAR_W"
    printf ' %s%3d%%%s' "$W" "$pct" "$NC"
    [[ -n "$extra" ]] && printf ' %s%s%s' "$D" "$extra" "$NC"
    printf '\n'
}

# ── Funciones de Datos ────────────────────────────────────────────────────────
get_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local v; v=$(cat /sys/class/thermal/thermal_zone0/temp)
        local g=$(awk "BEGIN{printf \"%.1f\", $v/1000}")
        if (( ${v%000} >= 70 )); then echo "$R$g°C$NC"; else echo "$G$g°C$NC"; fi
    else
        echo "${D}N/A${NC}"
    fi
}

get_uptime() {
    awk '{printf "%dd %dh %dm", $1/86400, ($1%86400)/3600, ($1%3600)/60}' /proc/uptime
}

get_disco() {
    df -k / 2>/dev/null | awk 'NR==2{printf "%d %d %d", $2/1024, $3/1024, $5}'
}

# ── Inicio de Pantalla ────────────────────────────────────────────────────────
tput smcup 2>/dev/null
printf '%s' "$HIDE"
stty -echo 2>/dev/null
clear

# ── Bucle principal ───────────────────────────────────────────────────────────
while true; do
    COLS=$(tput cols 2>/dev/null || echo 60)
    BAR_W=$(( COLS - 38 ))
    (( BAR_W < 10 )) && BAR_W=10
    (( BAR_W > 30 )) && BAR_W=30

    # Memoria en GB
    RAM_TOT_GB=$(awk '/MemTotal/{printf "%.2f", $2/1024/1024}' /proc/meminfo)
    RAM_USA_GB=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2; printf "%.2f", (t-a)/1024/1024}' /proc/meminfo)
    RAM_PCT=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2; printf "%d", (t-a)*100/t}' /proc/meminfo)

    UPTIME=$(get_uptime)
    LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
    TEMP=$(get_temp)
    read -r DSK_TOT DSK_USA DSK_PCT <<< "$(get_disco)"
    NOW=$(date '+%H:%M:%S')

    # Renderizado
    printf '\033[H'
    printf '%s ⚙ SYSINFO%s  %s%s@%s%s  %s%s%s\n' "$BOLD$M" "$NC" "$W" "$USER_NAME" "$C$HOST" "$NC" "$D" "$NOW" "$NC"
    div

    # SISTEMA
    printf '%s▸ SISTEMA%s\n' "$BOLD$Y" "$NC"
    campo "OS" "$W$OS$NC"
    campo "Kernel" "$W$KERNEL$NC"
    campo "Uptime" "$G$UPTIME$NC"
    campo "Carga" "$W$LOAD$NC"
    div

    # CPU
   # Mostrar cada core individual
    # --- BLOQUE CPU CORREGIDO ---
    printf '%s▸ CPU%s  %s%s%s\n' "$BOLD$Y" "$NC" "$D" "$CPU_MODEL" "$NC"
    campo "Temp CPU" "$TEMP"

    while read -r line; do
        if [[ $line =~ ^cpu[0-9]+ ]]; then
            core_id=$(echo "$line" | awk '{print $1}')

            # Usamos LC_NUMERIC=C para forzar que los decimales usen punto (.) y no coma (,)
            # Calculamos el uso restando el idle del total
            usage=$(awk -v core="$core_id" 'LC_NUMERIC=C $1 == core {total=$2+$3+$4+$5+$6+$7+$8; idle=$5; if(total>0) printf "%.0f", 100*(1-idle/total)}' /proc/stat)

            # Si por algún motivo sale vacío, asegurar que sea 0
            [[ -z "$usage" ]] && usage=0

            # Dibujar la fila del core
            fila_barra "$core_id" "$usage" ""
        fi
    done < /proc/stat
    div

    # MEMORIA
    printf '%s▸ MEMORIA%s\n' "$BOLD$Y" "$NC"
    fila_barra "RAM" "$RAM_PCT" "$RAM_USA_GB/$RAM_TOT_GB GB"
    div

    # DISCO
    printf '%s▸ DISCO%s\n' "$BOLD$Y" "$NC"
    fila_barra "/" "$DSK_PCT" "$DSK_USA/$DSK_TOT MB"
    div

    printf '  %sq%s salir  %s·%s  refresco %s%ds%s\n' "$W" "$NC" "$D" "$NC" "$W" "$INTERVALO" "$NC"
    printf '\033[J'

    IFS= read -r -s -n1 -t "$INTERVALO" key 2>/dev/null
    [[ "$key" == "q" || "$key" == "Q" ]] && salir
done
