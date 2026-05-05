#!/bin/bash

echo -e "PID\tUNIT/SERVICE\t\tSTATUS\t\tEXE_PATH"
echo -e "----------------------------------------------------------------------"

netstat -platun | awk '
# 1. Saltamos cabeceras y buscamos lineas con PID/Program
NR > 2 && $7 ~ /\// { 
    split($7, a, "/"); 
    pids[a[1]]++ 
} 

END { 
    for (p in pids) {
        # Obtener ruta real del ejecutable
        cmd_exe = "readlink -f /proc/" p "/exe 2>/dev/null"; 
        cmd_exe | getline exe; close(cmd_exe);

        # Obtener link crudo para detectar "(deleted)"
        cmd_raw = "ls -l /proc/" p "/exe 2>/dev/null";
        cmd_raw | getline raw; close(cmd_raw);

        # Obtener unidad de systemd
        cmd_unit = "ps -p " p " -o unit= --no-headers";
        cmd_unit | getline unit; close(cmd_unit);

        # Logica de deteccion
        status = "OK";
        if (raw ~ /deleted/) {
            status = "BACKDOOR(del)";
        } else if (exe ~ /^\/(tmp|var\/tmp|dev\/shm)/) {
            status = "SUSPICIOUS";
        }

        # Formatear salida (KISS)
        printf "%-7s\t%-20s\t%-12s\t%s\n", p, (unit==""?"init/manual":unit), status, exe;

        # Limpiar variables para evitar leaks en el loop de AWK
        exe=""; raw=""; unit="";
    }
}'
