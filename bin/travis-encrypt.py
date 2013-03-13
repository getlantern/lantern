#!/usr/bin/env python

if __name__ == "__main__":

    from Crypto.PublicKey import RSA
    import sys
    import base64

    pub_key = open("etc/travis.key.txt", "r").read()

    imp_key = RSA.importKey(pub_key)

    print base64.b64encode(imp_key.encrypt(sys.stdin.read(), 0)[0])
