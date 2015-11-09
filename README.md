# tunio

The `tunio` package captures and forwards TCP packets to a `net.Dialer` using a
TUN device (i.e.: it proxies every TCP packet that goes into the TUN device to
a `net.Dialer`).

`tunio` is able to forward UDP packets as well, but an external
[badvpn-udpgw](https://felixc.at/BadVPN) server is required.

## How to compile and run?

Throughout this example we are going to create a virtual machine and route all
its external traffic to a special TUN device, then we're going to listen on the
TUN device to capture TCP and UDP packets and forward them to another machine
running [Lantern](https://getlantern.org/) and `badvpn-udpgw`. Let's call this
machine the **proxy** and let's say the IP of the **proxy** is `10.4.4.120`.

So, before starting, make sure you're running both Lantern and `badvpn-udpgw`
on the proxy machine:

```sh
lantern -addr :2099
```

```sh
badvpn-udpgw --listen-addr 0.0.0.0:5353
```

And now let's create a virtual machine, here's the definition for a CentOS 7
virtual machine:

```
# Vagrantfile
Vagrant.configure(2) do |config|
  config.vm.box = "chef/centos-7.0"
  config.vm.network "private_network", ip: "192.168.88.10"
end
```

Use the `Vagrantfile` above to create a new virtual machine.

```sh
vagrant up
```

Log in into the newly created virtual machine and install some required
packages:

```sh
vagrant ssh
sudo yum install -y git gcc glibc-static

# Go
curl https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz \
	| sudo tar -xzv -C /usr/local/

echo 'export GOROOT=/usr/local/go'    >> $HOME/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin'  >> $HOME/.bashrc
echo 'export GOPATH=$HOME/go'         >> $HOME/.bashrc

source $HOME/.bashrc
```

Clone the `tunio` package into a projects directory:

```sh
mkdir -p projects
cd projects
git clone https://github.com/getlantern/tunio.git
cd tunio
go get -d -t .
```

Compile `tun2io`'s libraries with `make lib`:

```sh
make lib
# ...
# cc -shared -o lib/libtun2io.so tun2io.o ./obj/*.o -lrt -lpthread
# ar rcs lib/libtun2io.a tun2io.o ./obj/*.o
```

Create a new tun device, let's name it `tun0` and assign the `10.0.0.1` IP
address to it.

```sh
export ORIGINAL_GW=$(ip route  | grep default | awk '{print $3}')

export DEVICE_NAME=tun0
export DEVICE_IP=10.0.0.1

sudo ip tuntap del $DEVICE_NAME mode tun
sudo ip tuntap add $DEVICE_NAME mode tun
sudo ifconfig $DEVICE_NAME $DEVICE_IP netmask 255.255.255.0
```

Modify the routing table to only allow direct traffic with the proxy server
(`10.4.4.120`).

```sh
export PROXY_IP=10.4.4.120

sudo route add $PROXY_IP gw $ORIGINAL_GW metric 5
sudo route add default gw 10.0.0.2 metric 6
```

After altering the routing table you should not be able to ping external hosts:

```
ping google.com
PING google.com (74.125.227.165) 56(84) bytes of data.
^C
--- google.com ping statistics ---
5 packets transmitted, 0 received, 100% packet loss, time 4001ms
```

But you should be able to ping `$PROXY_IP`.

```
ping $PROXY_IP
PING 10.4.4.120 (10.4.4.120) 56(84) bytes of data.
64 bytes from 10.4.4.120: icmp_seq=1 ttl=63 time=3.45 ms
64 bytes from 10.4.4.120: icmp_seq=2 ttl=63 time=0.403 ms
^C
--- 10.4.4.120 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.403/1.928/3.454/1.526 ms
```

Now change directory to `tunio/cmd/tunio` and build the `tunio` command with
`go build`:

```sh
cd ~/go/src/github.com/getlantern/tunio/cmd/tunio
go build -v
```

Finally, run `tunio` with the `--proxy-addr` parameter pointing to Lantern and
with `--udpgw-remote-server-addr` pointing to `127.0.0.1:5353` (which is the
address of the udpgw server as Lantern sees it).

```sh
./tunio --tundev tun0 \
  --netif-ipaddr 10.0.0.2 \
  --netif-netmask 255.255.255.0 \
  --proxy-addr $PROXY_IP:2099 \
  --udpgw-remote-server-addr 127.0.0.1:5353
```

You should be able to browse any site now!

[1]: https://github.com/ambrop72/badvpn/tree/master/tun2socks
[2]: https://getlantern.org
