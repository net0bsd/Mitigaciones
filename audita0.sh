#!/bin/bash

# Script unificado: Instala auditoría, configura log local y reenvío remoto.
# Ejecutar como root.

# 1. Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ser ejecutado como root."
   exit 1
fi

# 2. Código a insertar en .bashrc
read -r -d '' AUDIT_CODE << 'EOF'

# --- INICIO SCRIPT AUDITORÍA ---
# SCRIPT AUDIT USER
if [ -z "$SUDO_USER" ]
        then
                SUDO_USER="No_SUDO"
fi
if [ -z "$SSH_CONNECTION" ]
        then
                SSH_CONNECTION="local"
fi
whoami="$(whoami)@$(echo $SSH_CONNECTION | awk '{print $1}')"
PROMPT_COMMAND=$(history -a;history -c;history -r)
typeset -r PROMPT_COMMAND
function log2syslog
{
      declare command
        command=$BASH_COMMAND
              logger -p local3.notice -t bash -i -- $USER : $whoami : ${SUDO_USER} : $$ : $PPID : $PWD : $command
}
trap log2syslog DEBUG
# --- FIN SCRIPT AUDITORÍA ---
EOF

# 3. Bucle para modificar .bashrc
echo "Iniciando configuración de .bashrc..."
for user_home in /home/*; do
    BASHRC_PATH="$user_home/.bashrc"
    if [ -f "$BASHRC_PATH" ]; then
        if ! grep -q "# --- INICIO SCRIPT AUDITORÍA ---" "$BASHRC_PATH"; then
            echo "Añadiendo código a: $BASHRC_PATH"
            echo "" >> "$BASHRC_PATH"
            echo "$AUDIT_CODE" >> "$BASHRC_PATH"
        else
            echo "El código ya existe en: $BASHRC_PATH. Omitiendo."
        fi
    fi
done
echo ".bashrc configurado."
echo ""

# 4. Configurar Rsyslog (ambos archivos)
RSYSLOG_AUDIT_CONF="/etc/rsyslog.d/60-bash-audit.conf"
RSYSLOG_REMOTE_CONF="/etc/rsyslog.d/50-remotos.conf"

echo "Configurando rsyslog..."

# Crear archivo para logs de auditoría local
cat > "$RSYSLOG_AUDIT_CONF" << EOF
# Guarda los comandos de los usuarios en un archivo dedicado
local3.notice                         /var/log/bash_audit.log
EOF
echo "Archivo de auditoría local creado en $RSYSLOG_AUDIT_CONF."

# Crear archivo para reenvío de logs a servidor central
cat > "$RSYSLOG_REMOTE_CONF" << EOF
# Reenvía todos los logs a un servidor central
*.* @@172.16.157.26:514
EOF
echo "Archivo de reenvío remoto creado en $RSYSLOG_REMOTE_CONF."
echo ""

# 5. Reiniciar el servicio rsyslog
echo "Reiniciando el servicio rsyslog para aplicar todos los cambios..."
if systemctl restart rsyslog; then
    echo "Servicio rsyslog reiniciado con éxito."
else
    echo "Error al reiniciar rsyslog. Revisa el estado con 'systemctl status rsyslog'."
fi

echo ""
echo "Proceso de configuración de logs y auditoría finalizado."
