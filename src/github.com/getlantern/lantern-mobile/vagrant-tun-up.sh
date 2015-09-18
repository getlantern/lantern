#!/bin/bash

if [ -z "$HOST_IP" ]; then
  echo "Please set HOST_IP"
  exit
fi

export ORIGINAL_GW=$(ip route  | grep default | awk '{print $3}')
export TUN2SOCKS_BINDIR=/opt/badvpn
export TUN2SOCKS_BIN=$TUN2SOCKS_BINDIR/tun2socks/badvpn-tun2socks

export DEVICE_NAME=tun0
export DEVICE_IP=10.0.0.1
export DEVICE_GW_IP=10.0.0.2

# Creating tun device.
sudo ip tuntap del $DEVICE_NAME mode tun
sudo ip tuntap add $DEVICE_NAME mode tun
sudo ifconfig $DEVICE_NAME $DEVICE_IP netmask 255.255.255.0

# Replacing nameservers
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

HOST_IP=10.0.0.101
sudo route add 8.8.8.8 gw $ORIGINAL_GW metric 5
sudo route add 8.8.4.4 gw $ORIGINAL_GW metric 5
sudo route add $HOST_IP gw $ORIGINAL_GW metric 5
sudo route add default gw $DEVICE_GW_IP metric 6

# Starting badvpn
killall -KILL badvpn-tun2socks
$TUN2SOCKS_BIN --tundev $DEVICE_NAME --netif-ipaddr $DEVICE_GW_IP --netif-netmask 255.255.255.0 --socks-server-addr $HOST_IP:8788
