# tunio

The tunio package can be used to redirect I/O from a tun device to a
`net.Dialer` by using a fork of [tun2socks][1] as a library.

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

Clone the `tunio` package and switch to the `badvpn-lwip` branch:

```
mkdir -p projects
cd projects
git clone https://github.com/getlantern/tunio.git
cd tunio
git checkout badvpn-lwip
go get -d -t .
```

Compile `tun2io`'s libraries:

```
make lib
# ...
# cc -shared -o lib/libtun2io.so tun2io.o ./obj/*.o -lrt -lpthread
# ar rcs lib/libtun2io.a tun2io.o ./obj/*.o
```

Create a new tun device, let's name it `tun0`.

```
#!/bin/bash
DEVICE_NAME=tun0
DEVICE_IP=10.0.0.1
sudo ip tuntap del $DEVICE_NAME mode tun
sudo ip tuntap add $DEVICE_NAME mode tun
sudo ifconfig $DEVICE_NAME $DEVICE_IP netmask 255.255.255.0
```

Replace the vm's name servers with `8.8.8.8` and `8.8.4.4`.

```
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
```

The easiest way to try the `net.Dialer` is by creating a transparent tunnel
with an external host, in this example we are going to use the vm's host as
external host.

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

But you should be able to ping the nameservers and `$HOST_IP`, because they're
using the original router.

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

Now you should be able to run the test!

```
go test
# ...
# PASS
# ok    _/home/vagrant/projects/tunio 1.260s
```

We used a transparent proxy for this test, but you are not bound to transparent
proxies only, it depends on the `net.Conn` returned by the `net.Dialer`. You
can also use socat to create a tcp-to-socks tunnel to simulate a `net.Conn`
over SOCKS:

```
# terminal 1
socat TCP-LISTEN:20443,fork socks:127.0.0.1:www.google.com:443,socksport=9999

# terminal 2
ssh -D 9999 remote@example.org
```

and a `net.Conn` over [Lantern][2]:

```
# terminal 1
socat TCP-LISTEN:20443,fork PROXY:127.0.0.1:www.google.com:443,proxyport=8787

# termina 2
lantern -role client -addr :8787
```

[1]: https://github.com/ambrop72/badvpn/tree/master/tun2socks
[2]: https://getlantern.org
