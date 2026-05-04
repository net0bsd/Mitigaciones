#!/bin/bash
# Title       : Universal Bashrc - Consultant Edition
# Author      : Ernesto Escobedo (net0bsd)
# Version     : 3.9
# --------------------------------------------------------------------------

# 1. PRE-CHECK: Evitar errores si se ejecuta en lugar de cargarse con source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: Este archivo debe cargarse con 'source .bashrc'"
    exit 1
fi
[[ $- != *i* ]] && return

# 2. DETECCIÓN DE ENTORNO
if [ -f /etc/os-release ]; then . /etc/os-release; DISTRO=$ID; fi

# 3. EL INVENTARIO DE CONSULTORÍA
check_tech_stack() {
    local net=(tcpdump arp-scan iftop iperf3 dig nmap nc arping mtr vnstat)
    local core=(sar iotop vim tmux jq goaccess htop sshpass openssl sysstat)
    local virt=(virt-top guestmount virt-filesystems qemu-img)
    local sec=(lynis rkhunter openscap-utils nikto clamscan)
    local all=("${net[@]}" "${core[@]}" "${virt[@]}" "${sec[@]}")
    local missing=()
    for tool in "${all[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then missing+=("$tool"); fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "\n\e[1;34m[!] STATUS DE ENTORNO - HOST: \e[1;37m$HOSTNAME\e[0m"
        echo -e "\e[1;33mHerramientas faltantes:\e[0m \e[0;31m${missing[*]}\e[0m\n"
    fi
}
check_tech_stack

# 4. GESTIÓN DE REPOSITORIOS Y SUSCRIPCIONES (RHEL/Suse Fix)
alias yum-clean='sudo yum clean all && sudo rm -rf /var/cache/yum && sudo yum repolist'
alias dnf-clean='sudo dnf clean all && sudo rm -rf /var/cache/dnf && sudo dnf repolist'
alias sub-fix='sudo subscription-manager refresh && sudo subscription-manager status'
alias sub-repos='sudo subscription-manager repos --list-enabled'

# 5. NMAP & NETWORK AUDIT
alias nm-vivos='sudo nmap -sn -n --min-rate 1000'
alias nm-full='sudo nmap -sS -Pn -n -vvv -p-'
alias nm-serv='sudo nmap -sV -sC -T4'
alias nm-vuln='sudo nmap -Pn --script vuln'
alias nm-ssl='sudo nmap --script ssl-cert,ssl-enum-ciphers'

# 6. ALIASES HISTÓRICOS (Tus favoritos)
export LS_OPTIONS='--color=auto'
alias ls='ls $LS_OPTIONS'; alias ll='ls $LS_OPTIONS -l'; alias l='ls $LS_OPTIONS -lA'; alias lc='ls -CF'
alias rm='rm -I --preserve-root'; alias mv='mv -i'; alias cp='cp -i'; alias ln='ln -i'
alias chown='chown --preserve-root'; alias chmod='chmod --preserve-root'; alias chgrp='chgrp --preserve-root'
alias wtf='watch -n 1 "w -hs"'; alias wth='ps -uxa | more'
alias bc='bc -l'; alias sha1='openssl sha1'; alias mkdir='mkdir -pv'; alias diff='colordiff'
alias h='history'; alias j='jobs -l'; alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'; alias nowtime='now'; alias nowdate='date +"%d-%m-%Y"'
alias ping='ping -c 5'; alias fastping='ping -c 100 -s.2'; alias ports='netstat -tulanp'
alias psmem='ps auxf | sort -nr -k 4'; alias pscpu='ps auxf | sort -nr -k 3'
alias meminfo='free -m -l -t'; alias cpuinfo='lscpu'

# 7. FUNCIONES DE CONSULTORÍA
scan-net() {
    local int=${1:-eth0}; local range=${2:-192.168.1.0/24}
    sudo arp-scan -I "$int" "$range" | awk '/[0-9]+\.[0-9]/{print $0}' | sort -t . -k1,1n -k2,2n -k3,3n -k4,4n | tee "netscan-$(date +%Y%m%d%H%M).txt"
}
cert-audit() { echo | openssl s_client -connect "$1":443 2>/dev/null | openssl x509 -noout -dates -subject; }
mount-img() { sudo guestmount -a "$1" -m /dev/sda2 --rw /mnt/m2 && echo "Montado en /mnt/m2"; }
alias umount-img='sudo guestunmount /mnt/m2'; alias v-info='qemu-img info'

# 8. SEGURIDAD DE PROMPT (CIS Hardening Immunity)
if (unset PROMPT_COMMAND 2>/dev/null); then
    export PROMPT_COMMAND='history -a; history -c; history -r'
    readonly PROMPT_COMMAND
fi

# 9. AUDITORÍA LOCAL & PROMPT
log2syslog() {
    local last_cmd="$BASH_COMMAND"
    [[ "$last_cmd" == *"logger"* ]] && return
    command -v logger >/dev/null && logger -p local3.notice -t "consultant_audit" -- "$USER : $PWD : $last_cmd"
}
trap log2syslog DEBUG

if [ $(id -u) -eq 0 ]; then
    PS1='[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;34m\]\H\[\e[m\]][\[\e[1;37m\]\w\[\e[m\]]\n# '
else
    PS1='[\[\e[1;32m\]\u\[\e[m\]@\[\e[1;34m\]\H\[\e[m\]][\[\e[1;37m\]\w\[\e[m\]]\n$ '
fi

# SSH Agent
if ! pgrep -u $USER ssh-agent > /dev/null; then eval $(ssh-agent -s) > /dev/null; fi