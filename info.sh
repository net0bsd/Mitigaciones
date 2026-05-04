#!/bin/bash
echo "------------------------------------- Inicio"
touch /forcefsck 
sysctl -p >/dev/null
uptime
echo "------------------------------------- USB"
lsusb |grep CH
echo "------------------------------------- log JOURNAL"
journalctl --no-pager --since today --grep 'fail|error|fatal' --output json|jq '._EXE' | sort | uniq -c | sort -k1h
journalctl  --vacuum-time=1d
echo "------------------------------------- latencia"
ping -c 3 -q 172.16.50.31 | grep -v 172.16.50.1
echo "------------------------------------- Fin"
