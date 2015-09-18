#!/bin/bash
export GO_URL=https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz

sudo yum install -y git gcc glibc-static cmake psmisc

# Building vanilla tun2socks
TUN2SOCKS_DIR=$HOME/projects/badvpn
TUN2SOCKS_BINDIR=/opt/badvpn
mkdir -p $TUN2SOCKS_DIR $TUN2SOCKS_BINDIR
git clone https://github.com/ambrop72/badvpn.git $TUN2SOCKS_DIR
cd $TUN2SOCKS_BINDIR
cmake $TUN2SOCKS_DIR -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_TUN2SOCKS=1
make

chmod +x /vagrant/vagrant-tun-up.sh

echo "Now login and run /vagrant/vagrant-tun-up.sh"
