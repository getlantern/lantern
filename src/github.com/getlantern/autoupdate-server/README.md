# autoupdate-server

The autoupdate-server package provides a server that allows Lantern clients to
compare their running software version against releases posted at
[Github](https://www.github.com), if a new version is available, the
autoupdate-server will provide a binary diff that the client can use to patch
itself.

## Features

* Uses Github releases.
* Generates binary diffs.

## Requisites

Make sure you have the [bsdiff](http://www.daemonology.net/bsdiff/) program
installed:

```
apt-get instal -y bsdiff
yum install -y bsdiff
brew install bsdiff
```

The `bsdiff` program is used to calculate a binary diff of two files and
generate a patch.

In order to sign binary files you'll need a keypair:

```sh
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -pubout
```

The private key must match the public key set in the autoupdate package
configuration.

## How to run the autoupdate server

```
./autoupdate-server -k private.pem
```

## Just testing?

Sure! Use this private key:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAzSoibtACnqcp2uTGjCMJtTOLDIMQ4oGPhGHT4Q/epum+H3hc
bBNs9jRnMRWgX4z++xxuNJnhmoJw0eUXB7B4vj5DYpPajq6gPY8JuraF4ngfP5ox
Kj2BqpEUR9bx+3SjOSInrirM0JZO+aAW38BQNJB+sS7JvbPjcwdjwKc5IKzc9kxx
JNoZoFE9GMnYzaOrAlpCuAKWH8SCXYtCTxsXfKexdDxsI5Vzm5lQHJLMeqhLTQTU
m9oQofwNAOGOkn6dD4ObMlmFTOsf1G03/Dl9sVgjaWaZ9bGjvJ9B85UxNeWwduy+
uMrqFytxG6bbq0PbDEVu6ZQCPyiyCA7l945JOQIDAQABAoIBAQC8AZh8I3HDITxh
srOfR5xlyE3rsU+PwVpa3arj2z8Vha0L+af4AfUfyPWnLUJBTVt7kZoL6derV007
isuH6Fc9PqFRfFwT1EJTJvireQdHePxptErJgoOIYlpLWtV0sHXCrWHfYKk/m/3T
ErjjYcAd6yuuAkos5OPRTTxEFvlqzlj20i/eWcV9OYQ6fo5YAttHyj2c/b8ZBO3u
aYSgeb6SUumzeUDii4CJZVjB9hFtWOy4o+RFcMa+hPb1ROjAVMWZE01fMZPTrAZb
H1ElQQ0iYbFOL9xf/TSvb+bIPEYtzp8gJJbcM+VKoRo5xnRD5htw2rPxTNilTB9Q
5ggZ0IzhAoGBAPPjFome0GKQWTO77FCsUrIX5UNF4EhM4ekj75Lh3kDun5HGhwPf
ezaKkbRV6B7selH2W3vRC7VaKTqxJdPqpqj2q1a2Id2/v1ly97X/4GEcfV50stj7
QNcDp4IhN1rgFNe21gJEU0jaCWVAAES9ItKcaAa04PLX5E0Qsvq+iic/AoGBANda
tT64BhV+ZNBuJJiBRddZQ2zhfsUU/aU/pX5YnPlsXgIekm9GVaFWklu8gmx5o/TU
mIOMwQFKKSSoNdIp0KFo+sAx4W7aNPlDhx67GkCcs/I1hi7sE8A4uf/C8Ix2ZXlf
qwOE5Hm4sIkrNOdMIwN/JndUcdDRZ6K8nQxndamHAoGBAONMFpomOEJUE76ieujo
4Z13pcUf35qihL17L3GuLixH+NGsu/KBGt1HIep3UgFYFdxDhRmNR6M6J0i7Bu1N
OQwp8J+82S1I4rYj7vdhRSZcnf8lNfYBnHmHv1sJSATa6LHuhd/Q++new3jowBdQ
Sp8NA+qUMz5AtVaZpKUKZcmTAoGAQRDl+/or1Gio2xS8N9uvF16f8ZC79Z3e+QOe
4+qwGug0Cx3jjn1IuANpGxB8s3uZHwrwvaZUVihq/+lWwZXitDH8uP8ZJp4FLV7K
v202hFkUQVUMoravTP+WqwDiHv5SsHZIPDr1sRUtOXR1eoDVf2P2Yk2ASeBLGK82
IB5OPZcCgYBfNKwnR0QRU0H7kyR6nU3F15mlqxzBQaE0gdXij5JPRpLcjG+RfX83
caUzdi/ZL6ov5cmnquTRnw8KW9Max9FPPyrrjTSW7h0ESTFcejvvQXyByPbWPwT1
BL0RSJZb4JgqCtRleQRcQg94+b4gvEllScprTHSQnIbrUVof79FoVQ==
-----END RSA PRIVATE KEY-----
```

Save it to `private.pem` and run the server pointing to the autoupdate-server
repo that belongs to the getlantern organization:

```sh
go run *.go -k private.pem -o getlantern -n autoupdate-server
# 2015/03/13 18:22:41 Starting release manager.
# 2015/03/13 18:22:41 Updating assets...
```

The private key above matches the public key the
https://github.com/getlantern/autoupdate/tree/master/_test_app example uses.

The first time you run the server, it will download all required assets, so
you'll probably need to wait a bit before the HTTP server is started.

Once you see the "Starting HTTP server" message you can continue testing a
running app.

```sh
# 2015/03/13 18:22:43 Starting up HTTP server at :9197.
```
