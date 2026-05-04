#!/bin/bash
# Configuración de Rsyslog para SRE Golden Signals

RSYSLOG_CONF="/etc/rsyslog.conf"
TIMESTAMP=$(date +%Y%m%d%H%M)
BACKUP_RSYSLOG="${RSYSLOG_CONF}.back-${TIMESTAMP}"

# 1. Backup de seguridad
cp "$RSYSLOG_CONF" "$BACKUP_RSYSLOG"

# 2. Configuración orientada a Señales Doradas
cat > /etc/rsyslog.d/99-sre-golden-signals.conf << EOF
# --- [ERRORES] ---
# Captura fallos de autenticación, kernel y errores de aplicaciones
auth,authpriv.*                 /var/log/auth.log
kern.err                        /var/log/kernel_errors.log
*.err;local3.notice             /var/log/errors_signals.log

# --- [TRÁFICO] ---
# Registra conexiones SSH y actividad de usuarios (vía local3 de tu script)
local3.info                     /var/log/traffic_audit.log

# --- [LATENCIA & SATURACIÓN] ---
# Logs de cron y mensajes del sistema que indican demoras o presión de recursos
cron.*                          /var/log/latency_cron.log
*.notice;*.info                 /var/log/saturation_metrics.log

# --- REENVÍO REMOTO (Tu Servidor Central) ---
*.* @@172.16.157.26:514
EOF

systemctl restart rsyslog
echo "Backup creado en $BACKUP_RSYSLOG y configuración de señales aplicada."
