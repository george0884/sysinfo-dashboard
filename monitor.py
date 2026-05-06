#!/usr/bin/env python3
import psutil, os, time, socket, platform

# Paleta de colores para que se vea como KDE/Konsole
C = {
    'hdr': '\033[1;34m', 'lbl': '\033[1;36m', 'val': '\033[0;37m', 
    'bar': '\033[0;32m', 'dim': '\033[2;37m', 'rst': '\033[0m', 'clr': '\033[H\033[J'
}

def get_uptime():
    with open('/proc/uptime', 'r') as f:
        seconds = float(f.readline().split()[0])
    return f"{int(seconds // 3600)}h {int((seconds % 3600) // 60)}m"

def draw_bar(pct, width=20):
    fill = int((pct or 0) * width / 100)
    return f"{C['dim']}[{C['bar']}{'█' * fill}{C['dim']}{'░' * (width - fill)}]{C['rst']} {C['val']}{pct:3.0f}%"

def main():
    try:
        while True:
            # Captura de datos
            cores = psutil.cpu_percent(interval=0.5, percpu=True)
            ram = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # Construcción de la pantalla (Sin parpadeos)
            out = [C['clr'] + f"{C['hdr']}OS:{C['rst']} {platform.system()} {platform.release()}"]
            out.append(f"{C['hdr']}Host:{C['rst']} {socket.gethostname()}")
            out.append(f"{C['hdr']}Kernel:{C['rst']} {platform.version().split()[0]}")
            out.append(f"{C['hdr']}Uptime:{C['rst']} {get_uptime()}")
            
            out.append(f"\n{C['lbl']}CPU Activity (Cores):{C['rst']}")
            for i, p in enumerate(cores):
                out.append(f"  {C['lbl']}Core {i:<2}:{C['rst']} {draw_bar(p)}")

            out.append(f"\n{C['lbl']}Resources:{C['rst']}")
            out.append(f"  {C['lbl']}Memory:{C['rst']} {draw_bar(ram.percent)} {ram.used/1e9:.1f}/{ram.total/1e9:.1f} GB")
            out.append(f"  {C['lbl']}Disk (/):{C['rst']} {draw_bar(disk.percent)} {disk.used/1e9:.1f}/{disk.total/1e9:.1f} GB")

            out.append(f"\n{C['dim']}{'-'*45}\n[Ctrl+C] Salir del Dashboard{C['rst']}")
            
            print("\n".join(out))
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nMonitor finalizado.")

if __name__ == "__main__":
    main()
