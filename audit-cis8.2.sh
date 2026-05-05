#!/bin/bash
# Title       : SRE Fortress & Compliance (Multi-Distro + AIDE)
# Description : Unifica CIS Auditd, Sysctl, Rsyslog, Sudo I/O, Bash Audit, Logrotate y AIDE.
# Target OS   : RHEL, CentOS, Alma, Rocky, Oracle, Debian, Ubuntu.
# Author      : Ernesto (net0bsd)
# Date        : 2026-05-05
# Version     : 8.2 (Unified SRE Edition + Centralized Backups)

set -euo pipefail
export LC_ALL=C
export LANG=C

# 1. Validación de privilegios
if [[ $EUID -ne 0 ]]; then
   echo "[!] Este script debe ser ejecutado como root."
   exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M)
BACKUP_DIR="/root/backup/cis/sre-backup-${TIMESTAMP}"
OS_FAMILY="unknown"

echo "=== Iniciando Hardening y Configuración SRE Full Stack ==="

# ==========================================
# FASE 00: INSTALACIÓN DE COMPLIANCE BASE
# ==========================================
echo "[*] Fase 00: Validando e instalando herramientas (Auditd, Logwatch, AIDE)..."
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null 2>&1
    apt-get install -y auditd logwatch aide >/dev/null 2>&1
    OS_FAMILY="debian"
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y audit logwatch aide >/dev/null 2>&1
    OS_FAMILY="rhel"
elif command -v yum >/dev/null 2>&1; then
    yum install -y audit logwatch aide >/dev/null 2>&1
    OS_FAMILY="rhel"
elif command -v zypper >/dev/null 2>&1; then
    zypper install -y audit logwatch aide >/dev/null 2>&1
    OS_FAMILY="suse"
else
    echo "  [!] Gestor de paquetes no detectado. Asumiendo binarios preinstalados."
fi

# ==========================================
# FASE 0.1: RESPALDO CENTRALIZADO
# ==========================================
echo "[*] Fase 0.1: Creando respaldo de seguridad centralizado..."
mkdir -p "$BACKUP_DIR"/{audit,rsyslog,sysctl,profile,logrotate,sudo,ssh,aide}
mkdir -p /var/log/status
mkdir -p /var/log/sudo
mkdir -p /var/log/logwatch
chmod 700 /var/log/sudo /var/log/logwatch
touch /var/log/status/user.log
chmod 640 /var/log/status/user.log

cp -a /etc/audit/rules.d/* "$BACKUP_DIR/audit/" 2>/dev/null
cp -a /etc/rsyslog.conf /etc/rsyslog.d/* "$BACKUP_DIR/rsyslog/" 2>/dev/null
cp -a /etc/sysctl.conf /etc/sysctl.d/* "$BACKUP_DIR/sysctl/" 2>/dev/null
cp -a /etc/profile.d/99-bash-audit.sh "$BACKUP_DIR/profile/" 2>/dev/null
cp -a /etc/logrotate.d/sre-fortress "$BACKUP_DIR/logrotate/" 2>/dev/null
cp -a /etc/ssh/sshd_config "$BACKUP_DIR/ssh/" 2>/dev/null
[ -f /etc/aide.conf ] && cp /etc/aide.conf "$BACKUP_DIR/aide/" 2>/dev/null
[ -f /etc/aide/aide.conf ] && cp /etc/aide/aide.conf "$BACKUP_DIR/aide/" 2>/dev/null

echo "  -> Respaldo completado en: $BACKUP_DIR"

# ==========================================
# FASE 0.2: PURGA E IDEMPOTENCIA
# ==========================================
echo "[*] Fase 0.2: Limpiando configuraciones legacy..."
find /etc/audit/rules.d/ -maxdepth 1 -type f -name "*.rules" -exec rm -f {} \;

if grep -qE '^[^#].*@@?' /etc/rsyslog.conf; then
    sed -i -e 's/^\([^#].*@@\)/# LOG_MIGRADO_SRE: \1/g' /etc/rsyslog.conf
fi

rm -f /etc/rsyslog.d/99-sre-golden-signals.conf
rm -f /etc/sysctl.d/99-sre-tuning.conf
echo "  -> Entorno purgado."

# ==========================================
# FASE 1: SSH VERBOSE & SUDO I/O FORENSICS
# ==========================================
echo "[*] Fase 1: Configurando SSH (Verbose) y Sudo I/O..."
if grep -q "^LogLevel" /etc/ssh/sshd_config; then
    sed -i 's/^LogLevel.*/LogLevel VERBOSE/' /etc/ssh/sshd_config
else
    sed -i '/SyslogFacility/a LogLevel VERBOSE' /etc/ssh/sshd_config
fi

SUDO_AUDIT="/etc/sudoers.d/99-sre-sudo-audit"
cat > "$SUDO_AUDIT" << 'EOF'
Defaults        log_host, log_year, logfile="/var/log/sudo.log"
Defaults        log_input, log_output
Defaults        iolog_dir="/var/log/sudo/%{user}"
EOF
chmod 440 "$SUDO_AUDIT"

# ==========================================
# FASE 2: BASH AUDIT
# ==========================================
echo "[*] Fase 2: Configurando Bash Audit..."
PROFILE_AUDIT="/etc/profile.d/99-bash-audit.sh"
cat > "$PROFILE_AUDIT" << 'EOF'
if [[ $- == *i* ]]; then
    PROMPT_COMMAND="history -a"
    typeset -r PROMPT_COMMAND

    function log2syslog {
          declare command
          command=$BASH_COMMAND
          logger -p local3.notice -t bash -i -- "$USER : $$ : $PWD : $command"
    }
    trap log2syslog DEBUG
fi
EOF
chmod 644 "$PROFILE_AUDIT"

# ==========================================
# FASE 3: AUDITD (CIS & Forense)
# ==========================================
echo "[*] Fase 3: Aplicando reglas CIS para Auditd..."
RULES_FILE="/etc/audit/rules.d/audit.rules"
cat > "$RULES_FILE" << EOF
-D
-b 8192
-f 1
-e 1
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k audit_time_rules
-w /etc/localtime -p wa -k audit_time_rules
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_locale
-w /etc/issue -p wa -k system_locale
-w /etc/issue.net -p wa -k system_locale
-w /etc/hosts -p wa -k system_locale
-w /etc/sysconfig/network -p wa -k system_locale
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/ssh -k lateral_movement
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/scp -k lateral_movement
-a always,exit -F arch=b64 -S execve -F path=/usr/sbin/sshd -k ssh_server
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /var/log/lastlog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-w /etc/sudoers -p wa -k priv_esc
-w /etc/sudoers.d/ -p wa -k priv_esc
-a always,exit -F arch=b64 -S open -S truncate -S ftruncate -S creat -S openat -S open_by_handle_at -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S open -S truncate -S ftruncate -S creat -S openat -S open_by_handle_at -F exit=-EPERM -k access_denied
-a always,exit -F arch=b64 -S execve -F euid=48 -k web_user_anomaly
-a always,exit -F arch=b64 -S execve -F euid=33 -k web_user_anomaly
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -F auid=4294967295 -k web_priv_esc
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-w /etc/rsyslog.conf -p wa -k rsyslog_config
-w /etc/rsyslog.d/ -p wa -k rsyslog_config
EOF

# ==========================================
# FASE 4: SYSCTL (Mega Tuning)
# ==========================================
echo "[*] Fase 4: Aplicando Tuning de Sysctl..."
SYSCTL_FILE="/etc/sysctl.d/99-sre-tuning.conf"
cat > "$SYSCTL_FILE" << EOF
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
kernel.printk = 4 4 1 7
kernel.panic = 10
kernel.sysrq = 0
kernel.shmmax = 4294967296
kernel.shmall = 4194304
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
vm.swappiness = 20
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
fs.file-max = 2097152
net.core.netdev_max_backlog = 262144
net.core.rmem_default = 31457280
net.core.rmem_max = 67108864
net.core.wmem_default = 31457280
net.core.wmem_max = 67108864
net.core.somaxconn = 65535
net.core.optmem_max = 25165824
net.netfilter.nf_conntrack_max = 10000000
net.netfilter.nf_conntrack_tcp_loose = 0
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 87380 33554432
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 400000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_fin_timeout = 10
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.all.forwarding = 0
EOF

# ==========================================
# FASE 5: COMPLIANCE (AIDE, Logwatch) & RSYSLOG
# ==========================================
echo "[*] Fase 5: Configurando AIDE, Logwatch, Rsyslog y Logrotate..."

if command -v aide >/dev/null 2>&1 || command -v aideinit >/dev/null 2>&1; then
    echo "  -> Inicializando base de datos AIDE (Esto puede tomar varios minutos)..."
    if [ "$OS_FAMILY" == "debian" ]; then
        aideinit >/dev/null 2>&1
        [ -f /var/lib/aide/aide.db.new ] && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        [ -f /var/lib/aide/aide.db.new.gz ] && cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    else
        aide --init >/dev/null 2>&1
        [ -f /var/lib/aide/aide.db.new.gz ] && mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    fi
    echo -e "#!/bin/bash\n/usr/sbin/aide --check > /var/log/aide_check.log 2>&1" > /etc/cron.daily/aide
    chmod 755 /etc/cron.daily/aide
fi

cat > /etc/cron.daily/00logwatch << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/logwatch/report_$(date +%Y%m%d).log"
/usr/sbin/logwatch --output file --filename $LOG_FILE --format text --detail High
EOF
chmod 755 /etc/cron.daily/00logwatch

cat > /etc/rsyslog.d/99-sre-golden-signals.conf << EOF
local3.*                        -/var/log/status/user.log
auth,authpriv.*                 /var/log/auth.log
kern.err                        /var/log/kernel_errors.log
*.err                           /var/log/errors_signals.log
cron.*                          /var/log/latency_cron.log
*.notice;*.info                 /var/log/saturation_metrics.log
*.* @@172.16.157.26:514
EOF

cat > /etc/logrotate.d/sre-fortress << EOF
/var/log/status/user.log
/var/log/sudo.log
/var/log/logwatch/*.log
/var/log/aide_check.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
    create 0640 root root
    postrotate
        /usr/bin/systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

# ==========================================
# FASE 6: REINICIO Y APLICACIÓN
# ==========================================
echo "[*] Fase 6: Reiniciando servicios y aplicando cambios..."
systemctl enable --now auditd >/dev/null 2>&1
sysctl -p "$SYSCTL_FILE" >/dev/null
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
systemctl restart rsyslog

# La carga del bash profile la enviamos al background o la suprimimos para evitar stdout en el script
source /etc/profile.d/99-bash-audit.sh >/dev/null 2>&1

augenrules --load >/dev/null 2>&1 || auditctl -R "$RULES_FILE" >/dev/null 2>&1

echo -e "\n[✓] FORTALEZA SRE APLICADA EXITOSAMENTE EN ENTORNO MULTI-DISTRO."
