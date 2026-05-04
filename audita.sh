#!/bin/bash
#Title		:Audita cis
#Description	:Logs Audit Rsyslog Sysctl
#Author		:Ernesto Escobedo (net0bsd) eescobedo@gmail.com
#Date		:20250430
#Version	:1.4
#Usage		:bash audita.sh
#Notes		:Backup, configuración de reglas CIS y rastreo de anomalías.

RULES_FILE="/etc/audit/rules.d/audit.rules"
TIMESTAMP=$(date +%Y%m%d%H%M)
BACKUP_FILE="${RULES_FILE}.back-${TIMESTAMP}"

# 1. Función de Seguridad: Backup Inmediato
function make_backup() {
    if [ -f "$RULES_FILE" ]; then
        echo "Salvando configuración actual en: $BACKUP_FILE"
        cp "$RULES_FILE" "$BACKUP_FILE"
    else
        echo "No existe archivo previo, iniciando configuración limpia."
    fi
}

# 2. Aplicación de Reglas CIS y SRE (Completo)
function apply_rules() {
    echo "Aplicando reglas de auditoría CIS y rastreo de movimientos laterales..."
    cat > "$RULES_FILE" << EOF
## 1. CONFIGURACIÓN INICIAL
-D
-b 8192
-f 1
-e 1

## 2. INTEGRIDAD DEL TIEMPO (CIS)
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k audit_time_rules
-w /etc/localtime -p wa -k audit_time_rules

## 3. IDENTIDAD Y GRUPOS (Integridad de /etc/*)
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

## 4. RED Y LOCALIZACIÓN
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_locale
-w /etc/issue -p wa -k system_locale
-w /etc/hosts -p wa -k system_locale

## 5. SSH Y MOVIMIENTOS LATERALES
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/ssh -k lateral_movement
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/scp -k lateral_movement
-a always,exit -F arch=b64 -S execve -F path=/usr/sbin/sshd -k ssh_server
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

## 6. LOGINS Y SESIONES
-w /var/log/lastlog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

## 7. EXTRACCIÓN DE PRIVILEGIOS Y SUDO
-w /etc/sudoers -p wa -k priv_esc
-w /etc/sudoers.d/ -p wa -k priv_esc

## 8. ACCESOS DENEGADOS (Señal de Errores)
-a always,exit -F arch=b64 -S open -S truncate -S ftruncate -S creat -S openat -S open_by_handle_at -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S open -S truncate -S ftruncate -S creat -S openat -S open_by_handle_at -F exit=-EPERM -k access_denied

## 9. MONITOREO DE USUARIOS DE SERVICIO (Apache/HTTPD)
-a always,exit -F arch=b64 -S execve -F euid=48 -k web_user_anomaly
-a always,exit -F arch=b64 -S execve -F euid=33 -k web_user_anomaly
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -F auid=4294967295 -k web_priv_esc

## 10. MÓDULOS DEL KERNEL
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

## 11. REGLAS DE RSYSLOG
-w /etc/rsyslog.conf -p wa -k rsyslog_config
-w /etc/rsyslog.d/ -p wa -k rsyslog_config

# -e 2 # Inmutabilidad desactivada para pruebas
EOF
}

# Ejecución
if [[ $EUID -ne 0 ]]; then
   echo "Debes ser root."
   exit 1
fi

make_backup
apply_rules

# Recargar reglas en el sistema
augenrules --load || auditctl -R "$RULES_FILE"

echo "Proceso finalizado. Configuración activa y respaldo creado."
