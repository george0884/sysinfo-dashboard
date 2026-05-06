#!/usr/bin/env python3
import psutil
import os
import time
import sys
import socket

# --- COLORES ---
C_CAT = '\033[1;34m' # Azul
C_LBL = '\033[1;36m' # Cian
C_VAL = '\033[0;37m' # Blanco
C_GRN = '\033[0;32m' # Verde
C_DIM = '\033[2;37m' # Gris
C_RST = '\033[0m'    # Reset
C_HOME = '\033[H'    # Inicio
C_CLR = '\033[J'     # Limpiar

def barra(pct, ancho=12):
    pct = max(0, min(100, pct or 0))
    relleno = int(pct * ancho / 100)
    return f"{C_DIM}[{C_GRN}{'█' * relleno}{C_DIM}{'░' * (ancho - relleno)}]{C_RST} {C_VAL}{pct:3.0f}%{C_RST}"

def main():
    print('\033[?25l', end="") # Ocultar cursor
    os.system('clear')
    
    try:
        while True:
            # Captura Segura de CPU
            try:
                # Si esto falla, saltamos al except
                cpu_pcts = psutil.cpu_percent(percpu=True)
            except:
                # Fallback: Solo carga total si los cores están bloqueados
                cpu_pcts = [psutil.cpu_percent(percpu=False)]

            ram = psutil.virtual_memory()
            disk = psutil.disk_usage('/')

            # Renderizado
            out = [C_HOME]
            out.append(f"{C_CAT}System Info (Compatible Mode):{C_RST}")
            out.append(f"  {C_LBL}{'Host:':<12}{C_RST} {socket.gethostname()}")
            
            # Bloque de Cores (Solo se muestra si hay permiso)
            out.append(f"\n{C_CAT}CPU Activity:{C_RST}")
            if len(cpu_pcts) > 1:
                for i, pct in enumerate(cpu_pcts):
                    out.append(f"  {C_LBL}Core {i:<2}:{C_RST}  {barra(pct)}")
            else:
                out.append(f"  {C_LBL}Total CPU:{C_RST} {barra(cpu_pcts[0])} {C_DIM}(Cores bloqueados por Android){C_RST}")

            # Bloque de Recursos (Esto casi nunca falla)
            out.append(f"\n{C_CAT}Resources:{C_RST}")
            out.append(f"  {C_LBL}{'RAM:':<12}{C_RST} {barra(ram.percent)} {ram.used/1e9:.1f}/{ram.total/1e9:.1f} GB")
            out.append(f"  {C_LBL}{'Disk:':<12}{C_RST} {barra(disk.percent)} {disk.used/1e9:.1f}/{disk.total/1e9:.1f} GB")

            out.append(f"\n{C_DIM}{'-'*40}{C_RST}")
            out.append(f"  [Ctrl+C] para Salir\033[J")

            sys.stdout.write("\n".join(out))
            sys.stdout.flush()
            time.sleep(1)

    except KeyboardInterrupt:
        print('\033[?25h' + "\n\nCerrado.")

if __name__ == "__main__":
    main()
