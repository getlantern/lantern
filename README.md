# tunio

The `tunio` package captures and encapsulates TCP packets and forwards them to
a Go `net.Dialer`.

UDP packets can also be processed by `tunio`, but an external
[badvpn-udpgw](https://felixc.at/BadVPN) server is required to capture and
forward those packets.

## How to compile and run?

Throughout this example we are going to create a virtual machine and proxy all
its TCP and UDP traffic to another machine which is running
[Lantern](https://getlantern.org/) and `badvpn-udpgw`. Let's call this machine
the host and let's say the IP of the host is `10.0.0.101`. You can also use two
different hosts to run those programs.

So, before starting, make sure you're running Lantern and badvpn-udpgw on their
respective hosts:

```
lantern -addr :2099
```

```
badvpn-udpgw --listen-addr 0.0.0.0:5353
```

And now let's create the virtual machine, here's the definition for a CentOS 7
virtual machine:

```
# Vagrantfile
Vagrant.configure(2) do |config|
  config.vm.box = "chef/centos-7.0"
  config.vm.network "private_network", ip: "192.168.88.10"
end
```

Use the `Vagrantfile` above to create a new virtual machine.

```
vagrant up
```

Log in into the newly created virtual machine and install some required
packages:

```
vagrant ssh
sudo yum install -y git gcc glibc-static

# Go
curl https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz | sudo tar -xzv -C /usr/local/

echo 'export GOROOT=/usr/local/go'    >> $HOME/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin'  >> $HOME/.bashrc
echo 'export GOPATH=$HOME/go'         >> $HOME/.bashrc

source $HOME/.bashrc
```

Clone the `tunio` package:

```
mkdir -p projects
cd projects
git clone https://github.com/getlantern/tunio.git
cd tunio
go get -d -t .
```

Compile `tun2io`'s libraries with `make lib`:

```
make lib
# ...
# cc -shared -o lib/libtun2io.so tun2io.o ./obj/*.o -lrt -lpthread
# ar rcs lib/libtun2io.a tun2io.o ./obj/*.o
```

Create a new tun device, let's name it `tun0` and assign the `10.0.0.1` IP
address to it.

```
#!/bin/bash
export ORIGINAL_GW=$(ip route  | grep default | awk '{print $3}')

export DEVICE_NAME=tun0
export DEVICE_IP=10.0.0.1

sudo ip tuntap del $DEVICE_NAME mode tun
sudo ip tuntap add $DEVICE_NAME mode tun
sudo ifconfig $DEVICE_NAME $DEVICE_IP netmask 255.255.255.0
```

Replace the virtual machine's name servers with `8.8.8.8` and `8.8.4.4`.

```
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
```

Modify the routing table to allow direct traffic with the external host
(`10.0.0.101`). If you're running `badvpn-udpgw` on a different IP remember to
add a route for it as well.

```
#!/bin/bash
LANTERN_IP=10.0.0.101
UDPGW_IP=10.4.4.120

ORIGINAL_GW=10.0.2.2

sudo route add $LANTERN_IP gw $ORIGINAL_GW metric 5
sudo route add $UDPGW_IP gw $ORIGINAL_GW metric 5
sudo route add default gw 10.0.0.2 metric 6
```

After altering the routing table, you should not be able to ping external
hosts:

```
ping google.com
PING google.com (74.125.227.165) 56(84) bytes of data.
^C
--- google.com ping statistics ---
5 packets transmitted, 0 received, 100% packet loss, time 4001ms
```

But you should be able to ping `$LANTERN_IP` and `$UDPGW_IP`.

```
ping $LANTERN_IP
PING 10.0.0.101 (10.0.0.101) 56(84) bytes of data.
64 bytes from 10.0.0.101: icmp_seq=1 ttl=63 time=3.45 ms
64 bytes from 10.0.0.101: icmp_seq=2 ttl=63 time=0.403 ms
^C
--- 10.0.0.101 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.403/1.928/3.454/1.526 ms
```

Now change directory to `tunio/cmd/tunio` and build the `tunio` command:

```
cd ~/go/src/github.com/getlantern/tunio/cmd/tunio
go build -v
```

Finally, run `tunio` with the `--proxy-addr` parameter pointing to Lantern and
with `--udpgw-remote-server-addr` pointing to the udpgw server.

```
./tunio --tundev tun0 \
  --netif-ipaddr 10.0.0.2 \
  --netif-netmask 255.255.255.0 \
  --proxy-addr $LANTERN_IP:2099 \
  --udpgw-remote-server-addr $UDPGW_IP:5353
```

You should be able to browse now!

[1]: https://github.com/ambrop72/badvpn/tree/master/tun2socks
[2]: https://getlantern.org
