#!/usr/bin/env python3
import psutil, os, time, socket, platform, sys

# Colores estilo KDE Neon
C = {
    'h': '\033[1;34m', 'l': '\033[1;36m', 'v': '\033[0;37m', 
    'b': '\033[0;32m', 'd': '\033[2;37m', 'r': '\033[0m',
    'top': '\033[H', 'clean': '\033[J'
}

def draw_bar(pct, w=12): # Barras más cortas para que no se corten en el celu
    pct = max(0, min(100, pct or 0))
    f = int(pct * w / 100)
    return f"{C['d']}[{C['b']}{'█' * f}{C['d']}{'░' * (w - f)}]{C['r']} {C['v']}{pct:3.0f}%"

def main():
    os.system('clear')
    print('\033[?25l', end="") # Oculta el cursor
    try:
        while True:
            # Obtener datos (percpu=True es vital para ver todos los cores)
            try:
                cpus = psutil.cpu_percent(interval=0.5, percpu=True)
            except:
                cpus = [psutil.cpu_percent()]
            
            mem = psutil.virtual_memory()
            uptime = "".join(os.popen("uptime -p").readlines()).replace("up ", "")

            # Construir salida fija
            out = [C['top'] + f"{C['h']}SISTEMA:{C['r']} {platform.release()}"]
            out.append(f"{C['h']}HOST:   {C['r']} {socket.gethostname()}")
            out.append(f"{C['h']}UPTIME: {C['r']} {uptime.strip()}")
            
            out.append(f"\n{C['l']}CPU CORES:{C['r']}")
            for i, p in enumerate(cpus):
                # Esto asegura que si tenés muchos cores, no se vaya de pantalla
                if i < 8: 
                    out.append(f" Core {i}: {draw_bar(p)}")

            out.append(f"\n{C['l']}RECURSOS:{C['r']}")
            out.append(f" RAM:  {draw_bar(mem.percent)} {mem.used/1e9:.1f}GB")
            
            out.append(f"\n{C['d']}{'-'*30}\n[Ctrl+C] Salir\033[J")
            
            sys.stdout.write("\n".join(out))
            sys.stdout.flush()
    except KeyboardInterrupt:
        print('\033[?25h' + "\nCerrado.")

if __name__ == "__main__":
    main()
