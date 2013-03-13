#!/usr/bin/env python

if __name__ == "__main__":

    from Crypto.PublicKey import RSA
    from Crypto.Cipher import PKCS1_OAEP 
    import sys
    import base64

    pub_key = open("etc/travis.key.txt", "r").read()

    imp_key = RSA.importKey(pub_key)

    cipher = PKCS1_OAEP.new(imp_key)
    ciphertext = cipher.encrypt(sys.stdin.read())

    print base64.b64encode(ciphertext)
