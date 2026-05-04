#!/bin/bash
#iptables -L -nv
WAN=br0
iptables -i $WAN -A INPUT  -s $1 -j LOG --log-prefix  "IP DROP INPUT A: "
iptables -i $WAN -A INPUT  -s $1 -j DROP
iptables -A OUTPUT  -s $1 -j DROP
iptables -i $WAN -A FORWARD  -s $1 -j DROP
iptables -L -nv --line-numbers|grep $1
