#!/bin/bash

# get the ip
IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
IPPREFIX=$(ip addr | grep $IP | awk '{ print $2 }')

# flush container ip
ip addr flush dev eth0

# setup the bridge
ip link add br0 type bridge
ip tuntap add tap0 mode tap
ip link set eth0 master br0
ip link set tap0 master br0
ip link set dev br0 up
ip link set dev tap0 up
