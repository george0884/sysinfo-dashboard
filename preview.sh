#!/bin/bash

# Definir colores (Estilo Inxi: azul para etiquetas, blanco para datos)
LBL='\033[1;34m' # Blue bold
TXT='\033[0m'    # Reset
VAL='\033[1;37m' # White bold

# Función para imprimir filas con formato
print_line() {
    printf "${LBL}%-12s${TXT} %s\n" "$1" "$2"
}

echo -e "${LBL}System:${TXT}"
print_line "  Host:" "$(hostname)"
print_line "  Kernel:" "$(uname -sr)"
print_line "  Uptime:" "$(uptime -p | sed 's/up //')"

echo -e "${LBL}CPU:${TXT}"
# Esto extrae el modelo de CPU de /proc/cpuinfo
cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
print_line "  Model:" "$cpu_model"

echo -e "${LBL}Memory:${TXT}"
# Extrae RAM usada y total usando 'free'
ram_info=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)", $3, $2, $3*100/$2}')
print_line "  Usage:" "$ram_info"

echo -e "${LBL}Battery:${TXT}"
# En Android/Termux, esto suele estar en /sys/class/power_supply/battery/
if [ -d "/sys/class/power_supply/battery" ]; then
    cap=$(cat /sys/class/power_supply/battery/capacity)
    stat=$(cat /sys/class/power_supply/battery/status)
    print_line "  Status:" "$cap% ($stat)"
fi
