#!/usr/bin/env python3
import psutil, os, time, socket, platform, sys

# Colores y comandos de control de terminal
C = {
    'hdr': '\033[1;34m', 'lbl': '\033[1;36m', 'val': '\033[0;37m', 
    'bar': '\033[0;32m', 'dim': '\033[2;37m', 'rst': '\033[0m',
    'home': '\033[H', 'clear': '\033[J' # HOME mueve el cursor al inicio, CLEAR limpia lo que sobra
}

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            seconds = float(f.readline().split()[0])
        return f"{int(seconds // 3600)}h {int((seconds % 3600) // 60)}m"
    except: return "N/A"

def draw_bar(pct, width=15):
    pct = max(0, min(100, pct or 0))
    fill = int(pct * width / 100)
    return f"{C['dim']}[{C['bar']}{'█' * fill}{C['dim']}{'░' * (width - fill)}]{C['rst']} {C['val']}{pct:3.0f}%"

def main():
    # Limpiamos la pantalla UNA SOLA VEZ al empezar
    os.system('clear')
    print('\033[?25l', end="") # Ocultar el cursor para que no parpadee
    
    try:
        while True:
            cores = psutil.cpu_percent(interval=0.5, percpu=True)
            ram = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # El secreto: Volver al inicio de la pantalla (\033[H) en lugar de imprimir líneas nuevas
            out = [C['home'] + f"{C['hdr']}SISTEMA:{C['rst']} {platform.system()} {platform.release()}"]
            out.append(f"{C['hdr']}Host:{C['rst']}    {socket.gethostname()}")
            out.append(f"{C['hdr']}Uptime:{C['rst']}  {get_uptime()}")
            
            out.append(f"\n{C['lbl']}CPU CORES:{C['rst']}")
            for i, p in enumerate(cores):
                out.append(f"  Core {i:<2}: {draw_bar(p)}")

            out.append(f"\n{C['lbl']}RECURSOS:{C['rst']}")
            out.append(f"  RAM:  {draw_bar(ram.percent)} {ram.used/1e9:.1f}GB")
            out.append(f"  DISK: {draw_bar(disk.percent)} {disk.used/1e9:.1f}GB")

            out.append(f"\n{C['dim']}{'-'*40}\n[Ctrl+C] para salir{C['rst']}\033[J")
            
            # Imprimir todo de un solo golpe
            sys.stdout.write("\n".join(out))
            sys.stdout.flush()
            
    except KeyboardInterrupt:
        print('\033[?25h' + "\n\nMonitor cerrado.") # Mostrar el cursor de nuevo al salir

if __name__ == "__main__":
    main()
