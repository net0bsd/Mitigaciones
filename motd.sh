#!/bin/bash
/usr/bin/cat /usr/local/bin/logo.txt>/etc/motd
/usr/bin/awk -F= '/PRETTY/{print $2}' /etc/os-release >> /etc/motd
/usr/bin/grep Model /proc/cpuinfo >> /etc/motd
/usr/sbin/ip a sh eth0 | awk '/ether/{print "MACADDRESS :",$2}' >> /etc/motd
/usr/sbin/ip a sh eth0 | awk '/inet/{print "IP LOCAL :",$2}' >>/etc/motd
echo "------------------------------------- Version">>/etc/motd
cat /etc/motd
