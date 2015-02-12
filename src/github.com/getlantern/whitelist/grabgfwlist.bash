#!/bin/bash
wget -q https://autoproxy-gfwlist.googlecode.com/svn/trunk/gfwlist.txt -O gfwlist.txt
openssl base64 -d -in gfwlist.txt -out out.txt
mv out.txt lists/gfwlist.txt
rm gfwlist.txt
