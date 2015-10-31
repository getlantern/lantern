#!/bin/bash

if [ -z "$HOST_IP" ]; then
  echo "Please set HOST_IP"
  exit
fi

export ORIGINAL_GW=$(ip route  | grep default | awk '{print $3}')

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

#sudo route add 8.8.8.8 gw $ORIGINAL_GW metric 5
#sudo route add 8.8.4.4 gw $ORIGINAL_GW metric 5
sudo route add 10.4.4.120 gw $ORIGINAL_GW metric 5
sudo route add $HOST_IP gw $ORIGINAL_GW metric 5
sudo route add default gw $DEVICE_GW_IP metric 6
sudo route del default gw $ORIGINAL_GW
