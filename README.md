# tunio

The tunio package can be used to redirect I/O traffic from a tun device to a
`net.Dialer`.

This is a work in progress.

## Proof of concept

Create a CentOS 7 virtual machine:

```
cat Vagrantfile
# Vagrantfile
Vagrant.configure(2) do |config|
  config.vm.box = "chef/centos-7.0"
  config.vm.network "private_network", ip: "192.168.88.10"
end

vagrant up
```

Log in into the VM and install required packages:

```
vagrant ssh
sudo yum install -y git gcc glibc-static

curl https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz | sudo tar -xzv -C /usr/local/

export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
```

Clone the `tunio` package and switch to the `badvpn-lwip` branch:

```
mkdir -p projects
cd projects
git clone https://github.com/getlantern/tunio.git
cd tunio
git checkout badvpn-lwip
```

Compile `tun2io`'s shared and static libraries:

```
make lib
# ...
# cc -shared -o lib/libtun2io.so tun2io.o ./obj/*.o -lrt -lpthread
# ar rcs lib/libtun2io.a tun2io.o ./obj/*.o
```

Create a new tun device on `tun0`.

```
#!/bin/bash
DEVICE_NAME=tun0
DEVICE_IP=10.0.0.1
sudo ip tuntap del $DEVICE_NAME mode tun
sudo ip tuntap add $DEVICE_NAME mode tun
sudo ifconfig $DEVICE_NAME $DEVICE_IP netmask 255.255.255.0
```

Replace system's name servers with `8.8.8.8` and `8.8.4.4`.

```
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
```

The easiest way to try the net.Dialer is by creating a transparent tunnel with
an external host, in this example we are going to use the vm's host as external
host.

Modify the routing table to allow direct traffic with the name servers and with
the external host.

```
#!/bin/bash
HOST_IP=10.0.0.105
ORIGINAL_GW=10.0.2.2
sudo route add 8.8.8.8 gw $ORIGINAL_GW metric 5
sudo route add 8.8.4.4 gw $ORIGINAL_GW metric 5
sudo route add $HOST_IP gw $ORIGINAL_GW metric 5
sudo route add default gw 10.0.0.2 metric 6
```

Any other package will pass through `10.0.0.2` (our `tun0` device).

After altering the routing table, you should not be able to ping external
hosts:

```
ping google.com
PING google.com (74.125.227.165) 56(84) bytes of data.
^C
--- google.com ping statistics ---
5 packets transmitted, 0 received, 100% packet loss, time 4001ms
```

But you should be able to ping the nameservers and `$HOST_IP`.

```
ping $HOST_IP
PING 10.0.0.105 (10.0.0.105) 56(84) bytes of data.
64 bytes from 10.0.0.105: icmp_seq=1 ttl=63 time=3.45 ms
64 bytes from 10.0.0.105: icmp_seq=2 ttl=63 time=0.403 ms
^C
--- 10.0.0.105 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.403/1.928/3.454/1.526 ms
```

Install `socat` in your host and open a transparent TCP tunnel from port
`20443` to `google.com:443`.

```
brew install socat
socat TCP-LISTEN:20443,fork TCP:www.google.com:443
```

Now you should be able to run the test:

```
go test
# ...
# PASS
# ok    _/home/vagrant/projects/tunio 1.260s
```
