#!/bin/bash
free -h
sync; echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/drop_caches
sync; echo 2 > /proc/sys/vm/drop_caches
swapoff -a && sudo swapon -a
free -h
