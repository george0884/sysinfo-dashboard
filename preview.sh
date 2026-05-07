#!/bin/bash
# =============================================================================
#  sysinfo.sh — Dashboard tiempo real | Termux/Android + Linux
#  Salir: q  o  Ctrl+C
# =============================================================================

# Colores con sintaxis $'...' para evitar escape codes literales
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

INTERVALO=1

# ── Salir limpio ──────────────────────────────────────────────────────────────
salir() {
    tput rmcup 2>/dev/null
    printf '%s\n' "$SHOW"
    stty echo 2>/dev/null
    echo "  Dashboard cerrado."
    exit 0
}
trap salir INT TERM EXIT

# ── Detectar ancho de terminal ────────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 60)
# Ancho de barra: adaptado al terminal (mínimo 10, máximo 30)
BAR_W=$(( COLS - 38 ))
(( BAR_W < 10 )) && BAR_W=10
(( BAR_W > 30 )) && BAR_W=30

# ── Datos estáticos ───────────────────────────────────────────────────────────
# Inicializar arrays para los cores
declare -a CPU_CORES_PREV
declare -a CPU_CORES_CURR
OS=$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
[[ -z "$OS" ]] && OS="$(uname -o 2>/dev/null || uname -s)"
KERNEL=$(uname -r)
HOST=$(hostname 2>/dev/null || echo "localhost")
USER_NAME=$(whoami 2>/dev/null || echo "${USER:-?}")
SHELL_NAME=$(basename "${SHELL:-bash}")
CPU_MODEL=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//')
[[ -z "$CPU_MODEL" ]] && CPU_MODEL=$(grep 'Hardware' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//')
[[ -z "$CPU_MODEL" ]] && CPU_MODEL="$(uname -m)"
CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")

# CPU stat previo
CPU_STAT_OK=false
[[ -r /proc/stat ]] && CPU_STAT_OK=true

if [ "$CPU_STAT_OK" = true ]; then
    # Carga inicial para tener datos de comparación
    mapfile -t CPU_CORES_PREV < <(grep '^cpu[0-9]' /proc/stat)
fi
# ── Funciones ─────────────────────────────────────────────────────────────────
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

    # Cambiamos el separador inicial para dar espacio
    printf '%s ' "$D"
    printf '%s%s' "$NC" "$color"
    # Usamos un bloque un poco más delgado si preferís, o mantenés el █ pero con espacios
    local i; for (( i=0; i<relleno; i++ )); do printf '┃'; done
    printf '%s' "$D"
    for (( i=0; i<vacio;   i++ )); do printf ' '; done # Espacio vacío en lugar de ░
    printf '%s│%s' "$D" "$NC"
}

# Línea horizontal que se adapta al ancho del terminal
div() {
    printf '%s' "$D"
    local i; for (( i=0; i<COLS && i<70; i++ )); do printf '─'; done
    printf '%s\n' "$NC"
}

# Campo: etiqueta (16 chars) + valor truncado al ancho disponible
campo() {
    local label="$1" valor="$2"
    local max_val=$(( COLS - 20 ))
    (( max_val < 10 )) && max_val=10
    printf '  %s%-16s%s ' "$C" "$label" "$NC"
    # Truncar valor si es muy largo (sin contar escapes ANSI)
    printf '%s\n' "$valor"
}

# Fila de barra: etiqueta + barra + porcentaje en una línea
fila_barra() {
    local label="$1" pct=$2 extra="$3"
    # Forzamos 12 caracteres para la etiqueta y agregamos un separador "┊"
    printf '  %s%-12s%s ┊' "$C" "$label" "$NC"
    barra "$pct" "$BAR_W"
    printf ' %s%3d%%%s' "$W" "$pct" "$NC"
    [[ -n "$extra" ]] && printf ' %s%s%s' "$D" "$extra" "$NC"
    printf '\n'
}

calc_cpu() {
    # Usamos awk para asegurar que solo procesamos números y evitar errores de sintaxis
    local uso=$(awk -v prev="$1" -v curr="$2" 'BEGIN {
        split(prev, p); split(curr, c);
        for(i=1; i<=7; i++) { dt += (c[i]-p[i]); }
        di = (c[4]+c[5]) - (p[4]+p[5]);
        if (dt <= 0) printf "0";
        else printf "%d", 100*(dt-di)/dt;
    }')
    echo "$uso"
}

get_temp() {
    for f in /sys/class/thermal/thermal_zone*/temp; do
        [[ -r "$f" ]] || continue
        local v; v=$(cat "$f" 2>/dev/null)
        [[ "$v" =~ ^[0-9]+$ ]] || continue
        (( v <= 1000 )) && continue
        local g=$(( v/1000 ))
        (( g<=0 || g>=120 )) && continue
        if   (( g>=80 )); then printf '%s%d°C%s' "$R" "$g" "$NC"
        elif (( g>=60 )); then printf '%s%d°C%s' "$Y" "$g" "$NC"
        else                   printf '%s%d°C%s' "$G" "$g" "$NC"
        fi
        return
    done
    printf '%sN/A%s' "$D" "$NC"
}

get_uptime() {
    if [[ -r /proc/uptime ]]; then
        local s; s=$(awk '{print int($1)}' /proc/uptime)
        local d=$(( s/86400 )) h=$(( (s%86400)/3600 )) m=$(( (s%3600)/60 ))
        local r=""
        (( d>0 )) && r="${d}d "
        (( h>0 )) && r+="${h}h "
        r+="${m}m"; echo "$r"
    else
        uptime -p 2>/dev/null | sed 's/up //' || echo "N/A"
    fi
}

get_load() {
    [[ -r /proc/loadavg ]] && awk '{print $1" "$2" "$3}' /proc/loadavg || echo "N/A"
}

get_disco() {
    # Usar bloques de 1K (compatible con Termux y Linux)
    # df -k garantiza números enteros sin sufijos
    local info; info=$(df -k / 2>/dev/null | awk 'NR==2{print $2,$3}')
    [[ -z "$info" ]] && echo "0 0 0" && return
    local tot_k uso_k
    tot_k=$(echo "$info" | awk '{print $1}')
    uso_k=$(echo "$info" | awk '{print $2}')
    # Validar que sean números
    [[ "$tot_k" =~ ^[0-9]+$ ]] || tot_k=1
    [[ "$uso_k" =~ ^[0-9]+$ ]] || uso_k=0
    # Convertir a MB con awk (evita errores de enteros grandes en bash)
    local tot_mb uso_mb pct
    tot_mb=$(awk "BEGIN{printf \"%d\", $tot_k/1024}")
    uso_mb=$(awk "BEGIN{printf \"%d\", $uso_k/1024}")
    pct=$(awk "BEGIN{printf \"%d\", $uso_k*100/$tot_k}")
    [[ "$tot_mb" =~ ^[0-9]+$ ]] || tot_mb=0
    [[ "$uso_mb" =~ ^[0-9]+$ ]] || uso_mb=0
    [[ "$pct"    =~ ^[0-9]+$ ]] || pct=0
    echo "$tot_mb $uso_mb $pct"
}

# ── Pantalla alternativa (una sola vez) ───────────────────────────────────────
tput smcup 2>/dev/null
printf '%s' "$HIDE"
stty -echo 2>/dev/null
clear

# ── Bucle principal ───────────────────────────────────────────────────────────
while true; do

    # Recalcular ancho en cada ciclo (el usuario puede redimensionar)
    COLS=$(tput cols 2>/dev/null || echo 60)
    BAR_W=$(( COLS - 38 ))
    (( BAR_W < 10 )) && BAR_W=10
    (( BAR_W > 30 )) && BAR_W=30

    # CPU
# CPU Data Gathering
    if [ "$CPU_STAT_OK" = true ]; then
        # Capturar estados actuales
        mapfile -t CPU_CORES_CURR < <(grep '^cpu[0-9]' /proc/stat)

        # Inicialización en primera corrida
        if [[ ${#CPU_CORES_PREV[@]} -eq 0 ]]; then
            CPU_CORES_PREV=("${CPU_CORES_CURR[@]}")
            sleep 0.1
            mapfile -t CPU_CORES_CURR < <(grep '^cpu[0-9]' /proc/stat)
        fi
    fi

    # Frecuencia
    # Obtener frecuencia actual promedio de todos los núcleos
    CPU_FREQ_STR=$(awk '{sum+=$1} END {if (NR>0) printf "%.1f GHz", sum/NR/1000000; else printf "N/A"}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
    [[ "$CPU_FREQ_STR" == "N/A" ]] && CPU_FREQ_STR=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{printf "%.1f GHz", $4/1000}')

    UPTIME=$(get_uptime)
    LOAD=$(get_load)

    RAM_TOT=$(awk '/MemTotal/{print $2}'     /proc/meminfo 2>/dev/null || echo 1)
    RAM_LIB=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_USA=$(( RAM_TOT - RAM_LIB ))
    RAM_PCT=$(( RAM_USA * 100 / RAM_TOT ))
    RAM_USA_MB=$(( RAM_USA / 1024 ))
    RAM_TOT_MB=$(( RAM_TOT / 1024 ))

    SWP_TOT=$(awk '/SwapTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
    SWP_LIB=$(awk '/SwapFree/{print $2}'  /proc/meminfo 2>/dev/null || echo 0)
    SWP_USA=$(( SWP_TOT - SWP_LIB ))
    SWP_PCT=0
    SWP_TOT_MB=$(( SWP_TOT / 1024 ))
    SWP_USA_MB=$(( SWP_USA / 1024 ))
    (( SWP_TOT > 0 )) && SWP_PCT=$(( SWP_USA * 100 / SWP_TOT ))

    read -r DSK_TOT DSK_USA DSK_PCT <<< "$(get_disco)"

    IFACE=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    [[ -z "$IFACE" ]] && IFACE=$(ip link 2>/dev/null | awk -F: '/^[0-9]+: [a-z]/{gsub(/ /,"",$2); if($2!="lo"){print $2;exit}}')
    if [[ -n "$IFACE" && "$IFACE" != "N/A" ]]; then
        IP_LOCAL=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
        RX=$(cat /sys/class/net/"$IFACE"/statistics/rx_bytes 2>/dev/null || echo 0)
        TX=$(cat /sys/class/net/"$IFACE"/statistics/tx_bytes 2>/dev/null || echo 0)
        RX_MB=$(awk "BEGIN{printf \"%.0f\", $RX/1048576}")
        TX_MB=$(awk "BEGIN{printf \"%.0f\", $TX/1048576}")
    else
        IFACE="N/A"; IP_LOCAL="N/A"; RX_MB=0; TX_MB=0
    fi

    TEMP=$(get_temp)
    PROCS=$(ps -e --no-headers 2>/dev/null | wc -l || ps 2>/dev/null | tail -n +2 | wc -l)
    PROCS_R=$(ps -eo stat --no-headers 2>/dev/null | grep -c '^R' || echo 0)
    NOW=$(date '+%Y-%m-%d %H:%M:%S')

    # ── Render (sin clear, solo reposicionar) ─────────────────────────────────
    printf '\033[H'   # cursor a (0,0)

    # Cabecera compacta (1 línea)
    printf '%s ⚙ SYSINFO%s  %s%s@%s%s  %s%s%s\n' \
        "$BOLD$M" "$NC" "$W" "$USER_NAME" "$C$HOST" "$NC" "$D" "$NOW" "$NC"
    div

    # SISTEMA
    printf '%s▸ SISTEMA%s\n' "$BOLD$Y" "$NC"
    campo  "OS"        "$W$OS$NC"
    campo  "Kernel"    "$W$KERNEL$NC"
    campo  "Uptime"    "$G$UPTIME$NC"
    campo  "Carga"     "${W}${LOAD}${NC} ${D}(1m 5m 15m)${NC}"
    campo  "Procesos"  "${W}${PROCS}${NC} total  ${G}${PROCS_R}${NC} activos"
    div

    # CPU
    # Cabecera de CPU
    printf '%s▸ CPU%s  %s%s%s  %s%s%s  %sTemp: %s%s\n' \
        "$BOLD$Y" "$NC" "$D" "$CPU_MODEL" "$NC" "$G" "$CPU_FREQ_STR" "$NC" "$D" "$TEMP" "$NC"

# Generar una barra por cada núcleo
    if [ "$CPU_STAT_OK" = true ]; then
        mapfile -t CPU_CORES_CURR < <(grep '^cpu[0-9]' /proc/stat)

        for i in "${!CPU_CORES_CURR[@]}"; do
            curr_data=$(echo "${CPU_CORES_CURR[$i]}" | cut -d' ' -f2-)
            prev_data=$(echo "${CPU_CORES_PREV[$i]}" | cut -d' ' -f2-)

            if [[ -n "$curr_data" && -n "$prev_data" ]]; then
                CORE_USO=$(calc_cpu "$prev_data" "$curr_data")
                # Solo el número del core para ahorrar espacio
                fila_barra "cpu_$i" "$CORE_USO" ""
            fi
            CPU_CORES_PREV[$i]="${CPU_CORES_CURR[$i]}"
        done
    fi
    div

    # MEMORIA
    printf '%s▸ MEMORIA%s\n' "$BOLD$Y" "$NC"
    fila_barra "RAM ${D}${RAM_USA_MB}/${RAM_TOT_MB}M${NC}" "$RAM_PCT" ""
    if (( SWP_TOT_MB > 0 )); then
        fila_barra "SWAP ${D}${SWP_USA_MB}/${SWP_TOT_MB}M${NC}" "$SWP_PCT" ""
    else
        printf '  %sSWAP%s            %sNo configurada%s\n' "$C" "$NC" "$D" "$NC"
    fi
    div

    # DISCO
    printf '%s▸ DISCO%s\n' "$BOLD$Y" "$NC"
    fila_barra "/ ${D}${DSK_USA}/${DSK_TOT}M${NC}" "$DSK_PCT" ""
    div

    # RED
    printf '%s▸ RED%s  %s%s%s  %s%s%s\n' \
        "$BOLD$Y" "$NC" "$W" "$IFACE" "$NC" "$D" "${IP_LOCAL:-N/A}" "$NC"
    campo "Recibido"  "${G}↓ ${RX_MB} MB${NC}"
    campo "Enviado"   "${Y}↑ ${TX_MB} MB${NC}"
    div

    printf '  %sq%s salir  %s·%s  refresco %s%ds%s\n' \
        "$W" "$NC" "$D" "$NC" "$W" "$INTERVALO" "$NC"

    # Limpiar líneas sobrantes hasta el final de pantalla
    printf '\033[J'

    # Esperar input o timeout
    IFS= read -r -s -n1 -t "$INTERVALO" key 2>/dev/null
    [[ "$key" == "q" || "$key" == "Q" ]] && salir

done
