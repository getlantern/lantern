# -*- coding: utf-8 -*-
#
#  SelfTest/PublicKey/test_importKey.py: Self-test for importing RSA keys
#
# ===================================================================
# The contents of this file are dedicated to the public domain.  To
# the extent that dedication to the public domain is not available,
# everyone is granted a worldwide, perpetual, royalty-free,
# non-exclusive license to exercise all rights associated with the
# contents of this file for any purpose whatsoever.
# No rights are reserved.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ===================================================================

from __future__ import nested_scopes

__revision__ = "$Id$"

import unittest

from Crypto.PublicKey import RSA
from Crypto.SelfTest.st_common import *
from Crypto.Util.py3compat import *
from Crypto.Util.number import inverse
from Crypto.Util import asn1

def der2pem(der, text='PUBLIC'):
    import binascii
    chunks = [ binascii.b2a_base64(der[i:i+48]) for i in range(0, len(der), 48) ]
    pem  = b('-----BEGIN %s KEY-----\n' % text)
    pem += b('').join(chunks)
    pem += b('-----END %s KEY-----' % text)
    return pem

class ImportKeyTests(unittest.TestCase):
    # 512-bit RSA key generated with openssl
    rsaKeyPEM = u'''-----BEGIN RSA PRIVATE KEY-----
MIIBOwIBAAJBAL8eJ5AKoIsjURpcEoGubZMxLD7+kT+TLr7UkvEtFrRhDDKMtuII
q19FrL4pUIMymPMSLBn3hJLe30Dw48GQM4UCAwEAAQJACUSDEp8RTe32ftq8IwG8
Wojl5mAd1wFiIOrZ/Uv8b963WJOJiuQcVN29vxU5+My9GPZ7RA3hrDBEAoHUDPrI
OQIhAPIPLz4dphiD9imAkivY31Rc5AfHJiQRA7XixTcjEkojAiEAyh/pJHks/Mlr
+rdPNEpotBjfV4M4BkgGAA/ipcmaAjcCIQCHvhwwKVBLzzTscT2HeUdEeBMoiXXK
JACAr3sJQJGxIQIgarRp+m1WSKV1MciwMaTOnbU7wxFs9DP1pva76lYBzgUCIQC9
n0CnZCJ6IZYqSt0H5N7+Q+2Ro64nuwV/OSQfM6sBwQ==
-----END RSA PRIVATE KEY-----'''

    # As above, but this is actually an unencrypted PKCS#8 key
    rsaKeyPEM8 = u'''-----BEGIN PRIVATE KEY-----
MIIBVQIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEAvx4nkAqgiyNRGlwS
ga5tkzEsPv6RP5MuvtSS8S0WtGEMMoy24girX0WsvilQgzKY8xIsGfeEkt7fQPDj
wZAzhQIDAQABAkAJRIMSnxFN7fZ+2rwjAbxaiOXmYB3XAWIg6tn9S/xv3rdYk4mK
5BxU3b2/FTn4zL0Y9ntEDeGsMEQCgdQM+sg5AiEA8g8vPh2mGIP2KYCSK9jfVFzk
B8cmJBEDteLFNyMSSiMCIQDKH+kkeSz8yWv6t080Smi0GN9XgzgGSAYAD+KlyZoC
NwIhAIe+HDApUEvPNOxxPYd5R0R4EyiJdcokAICvewlAkbEhAiBqtGn6bVZIpXUx
yLAxpM6dtTvDEWz0M/Wm9rvqVgHOBQIhAL2fQKdkInohlipK3Qfk3v5D7ZGjrie7
BX85JB8zqwHB
-----END PRIVATE KEY-----'''

    # The same RSA private key as in rsaKeyPEM, but now encrypted
    rsaKeyEncryptedPEM=(
            
        # With DES and passphrase 'test'
        ('test', u'''-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-CBC,AF8F9A40BD2FA2FC

Ckl9ex1kaVEWhYC2QBmfaF+YPiR4NFkRXA7nj3dcnuFEzBnY5XULupqQpQI3qbfA
u8GYS7+b3toWWiHZivHbAAUBPDIZG9hKDyB9Sq2VMARGsX1yW1zhNvZLIiVJzUHs
C6NxQ1IJWOXzTew/xM2I26kPwHIvadq+/VaT8gLQdjdH0jOiVNaevjWnLgrn1mLP
BCNRMdcexozWtAFNNqSzfW58MJL2OdMi21ED184EFytIc1BlB+FZiGZduwKGuaKy
9bMbdb/1PSvsSzPsqW7KSSrTw6MgJAFJg6lzIYvR5F4poTVBxwBX3+EyEmShiaNY
IRX3TgQI0IjrVuLmvlZKbGWP18FXj7I7k9tSsNOOzllTTdq3ny5vgM3A+ynfAaxp
dysKznQ6P+IoqML1WxAID4aGRMWka+uArOJ148Rbj9s=
-----END RSA PRIVATE KEY-----''',
        "\xAF\x8F\x9A\x40\xBD\x2F\xA2\xFC"),

        # With Triple-DES and passphrase 'rocking'
        ('rocking', u'''-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,C05D6C07F7FC02F6

w4lwQrXaVoTTJ0GgwY566htTA2/t1YlimhxkxYt9AEeCcidS5M0Wq9ClPiPz9O7F
m6K5QpM1rxo1RUE/ZyI85gglRNPdNwkeTOqit+kum7nN73AToX17+irVmOA4Z9E+
4O07t91GxGMcjUSIFk0ucwEU4jgxRvYscbvOMvNbuZszGdVNzBTVddnShKCsy9i7
nJbPlXeEKYi/OkRgO4PtfqqWQu5GIEFVUf9ev1QV7AvC+kyWTR1wWYnHX265jU5c
sopxQQtP8XEHIJEdd5/p1oieRcWTCNyY8EkslxDSsrf0OtZp6mZH9N+KU47cgQtt
9qGORmlWnsIoFFKcDohbtOaWBTKhkj5h6OkLjFjfU/sBeV1c+7wDT3dAy5tawXjG
YSxC7qDQIT/RECvV3+oQKEcmpEujn45wAnkTi12BH30=
-----END RSA PRIVATE KEY-----''',
        "\xC0\x5D\x6C\x07\xF7\xFC\x02\xF6"),
    )

    rsaPublicKeyPEM = u'''-----BEGIN PUBLIC KEY-----
MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL8eJ5AKoIsjURpcEoGubZMxLD7+kT+T
Lr7UkvEtFrRhDDKMtuIIq19FrL4pUIMymPMSLBn3hJLe30Dw48GQM4UCAwEAAQ==
-----END PUBLIC KEY-----'''

    # Obtained using 'ssh-keygen -i -m PKCS8 -f rsaPublicKeyPEM'
    rsaPublicKeyOpenSSH = '''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAQQC/HieQCqCLI1EaXBKBrm2TMSw+/pE/ky6+1JLxLRa0YQwyjLbiCKtfRay+KVCDMpjzEiwZ94SS3t9A8OPBkDOF comment\n'''

    # The private key, in PKCS#1 format encoded with DER
    rsaKeyDER = a2b_hex(
    '''3082013b020100024100bf1e27900aa08b23511a5c1281ae6d93312c3efe
    913f932ebed492f12d16b4610c328cb6e208ab5f45acbe2950833298f312
    2c19f78492dedf40f0e3c190338502030100010240094483129f114dedf6
    7edabc2301bc5a88e5e6601dd7016220ead9fd4bfc6fdeb75893898ae41c
    54ddbdbf1539f8ccbd18f67b440de1ac30440281d40cfac839022100f20f
    2f3e1da61883f62980922bd8df545ce407c726241103b5e2c53723124a23
    022100ca1fe924792cfcc96bfab74f344a68b418df578338064806000fe2
    a5c99a023702210087be1c3029504bcf34ec713d877947447813288975ca
    240080af7b094091b12102206ab469fa6d5648a57531c8b031a4ce9db53b
    c3116cf433f5a6f6bbea5601ce05022100bd9f40a764227a21962a4add07
    e4defe43ed91a3ae27bb057f39241f33ab01c1
    '''.replace(" ",""))

    # The private key, in unencrypted PKCS#8 format encoded with DER
    rsaKeyDER8 = a2b_hex(
    '''30820155020100300d06092a864886f70d01010105000482013f3082013
    b020100024100bf1e27900aa08b23511a5c1281ae6d93312c3efe913f932
    ebed492f12d16b4610c328cb6e208ab5f45acbe2950833298f3122c19f78
    492dedf40f0e3c190338502030100010240094483129f114dedf67edabc2
    301bc5a88e5e6601dd7016220ead9fd4bfc6fdeb75893898ae41c54ddbdb
    f1539f8ccbd18f67b440de1ac30440281d40cfac839022100f20f2f3e1da
    61883f62980922bd8df545ce407c726241103b5e2c53723124a23022100c
    a1fe924792cfcc96bfab74f344a68b418df578338064806000fe2a5c99a0
    23702210087be1c3029504bcf34ec713d877947447813288975ca240080a
    f7b094091b12102206ab469fa6d5648a57531c8b031a4ce9db53bc3116cf
    433f5a6f6bbea5601ce05022100bd9f40a764227a21962a4add07e4defe4
    3ed91a3ae27bb057f39241f33ab01c1
    '''.replace(" ",""))

    rsaPublicKeyDER = a2b_hex(
    '''305c300d06092a864886f70d0101010500034b003048024100bf1e27900a
    a08b23511a5c1281ae6d93312c3efe913f932ebed492f12d16b4610c328c
    b6e208ab5f45acbe2950833298f3122c19f78492dedf40f0e3c190338502
    03010001
    '''.replace(" ",""))

    n = long('BF 1E 27 90 0A A0 8B 23 51 1A 5C 12 81 AE 6D 93 31 2C 3E FE 91 3F 93 2E BE D4 92 F1 2D 16 B4 61 0C 32 8C B6 E2 08 AB 5F 45 AC BE 29 50 83 32 98 F3 12 2C 19 F7 84 92 DE DF 40 F0 E3 C1 90 33 85'.replace(" ",""),16)
    e = 65537L
    d = long('09 44 83 12 9F 11 4D ED F6 7E DA BC 23 01 BC 5A 88 E5 E6 60 1D D7 01 62 20 EA D9 FD 4B FC 6F DE B7 58 93 89 8A E4 1C 54 DD BD BF 15 39 F8 CC BD 18 F6 7B 44 0D E1 AC 30 44 02 81 D4 0C FA C8 39'.replace(" ",""),16)
    p = long('00 F2 0F 2F 3E 1D A6 18 83 F6 29 80 92 2B D8 DF 54 5C E4 07 C7 26 24 11 03 B5 E2 C5 37 23 12 4A 23'.replace(" ",""),16)
    q = long('00 CA 1F E9 24 79 2C FC C9 6B FA B7 4F 34 4A 68 B4 18 DF 57 83 38 06 48 06 00 0F E2 A5 C9 9A 02 37'.replace(" ",""),16)

    # This is q^{-1} mod p). fastmath and slowmath use pInv (p^{-1}
    # mod q) instead!
    qInv = long('00 BD 9F 40 A7 64 22 7A 21 96 2A 4A DD 07 E4 DE FE 43 ED 91 A3 AE 27 BB 05 7F 39 24 1F 33 AB 01 C1'.replace(" ",""),16)
    pInv = inverse(p,q)

    def testImportKey1(self):
        """Verify import of RSAPrivateKey DER SEQUENCE"""
        key = self.rsa.importKey(self.rsaKeyDER)
        self.failUnless(key.has_private())
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)
        self.assertEqual(key.d, self.d)
        self.assertEqual(key.p, self.p)
        self.assertEqual(key.q, self.q)

    def testImportKey2(self):
        """Verify import of SubjectPublicKeyInfo DER SEQUENCE"""
        key = self.rsa.importKey(self.rsaPublicKeyDER)
        self.failIf(key.has_private())
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)

    def testImportKey3unicode(self):
        """Verify import of RSAPrivateKey DER SEQUENCE, encoded with PEM as unicode"""
        key = RSA.importKey(self.rsaKeyPEM)
        self.assertEqual(key.has_private(),True) # assert_
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)
        self.assertEqual(key.d, self.d)
        self.assertEqual(key.p, self.p)
        self.assertEqual(key.q, self.q)

    def testImportKey3bytes(self):
        """Verify import of RSAPrivateKey DER SEQUENCE, encoded with PEM as byte string"""
        key = RSA.importKey(b(self.rsaKeyPEM))
        self.assertEqual(key.has_private(),True) # assert_
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)
        self.assertEqual(key.d, self.d)
        self.assertEqual(key.p, self.p)
        self.assertEqual(key.q, self.q)

    def testImportKey4unicode(self):
        """Verify import of RSAPrivateKey DER SEQUENCE, encoded with PEM as unicode"""
        key = RSA.importKey(self.rsaPublicKeyPEM)
        self.assertEqual(key.has_private(),False) # failIf
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)

    def testImportKey4bytes(self):
        """Verify import of SubjectPublicKeyInfo DER SEQUENCE, encoded with PEM as byte string"""
        key = RSA.importKey(b(self.rsaPublicKeyPEM))
        self.assertEqual(key.has_private(),False) # failIf
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)

    def testImportKey5(self):
        """Verifies that the imported key is still a valid RSA pair"""
        key = RSA.importKey(self.rsaKeyPEM)
        idem = key.encrypt(key.decrypt(b("Test")),0)
        self.assertEqual(idem[0],b("Test"))

    def testImportKey6(self):
        """Verifies that the imported key is still a valid RSA pair"""
        key = RSA.importKey(self.rsaKeyDER)
        idem = key.encrypt(key.decrypt(b("Test")),0)
        self.assertEqual(idem[0],b("Test"))

    def testImportKey7(self):
        """Verify import of OpenSSH public key"""
        key = self.rsa.importKey(self.rsaPublicKeyOpenSSH)
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)

    def testImportKey8(self):
        """Verify import of encrypted PrivateKeyInfo DER SEQUENCE"""
        for t in self.rsaKeyEncryptedPEM:
            key = self.rsa.importKey(t[1], t[0])
            self.failUnless(key.has_private())
            self.assertEqual(key.n, self.n)
            self.assertEqual(key.e, self.e)
            self.assertEqual(key.d, self.d)
            self.assertEqual(key.p, self.p)
            self.assertEqual(key.q, self.q)

    def testImportKey9(self):
        """Verify import of unencrypted PrivateKeyInfo DER SEQUENCE"""
        key = self.rsa.importKey(self.rsaKeyDER8)
        self.failUnless(key.has_private())
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)
        self.assertEqual(key.d, self.d)
        self.assertEqual(key.p, self.p)
        self.assertEqual(key.q, self.q)

    def testImportKey10(self):
        """Verify import of unencrypted PrivateKeyInfo DER SEQUENCE, encoded with PEM"""
        key = self.rsa.importKey(self.rsaKeyPEM8)
        self.failUnless(key.has_private())
        self.assertEqual(key.n, self.n)
        self.assertEqual(key.e, self.e)
        self.assertEqual(key.d, self.d)
        self.assertEqual(key.p, self.p)
        self.assertEqual(key.q, self.q)

    def testImportKey11(self):
        """Verify import of RSAPublicKey DER SEQUENCE"""
        der = asn1.DerSequence([17, 3]).encode()
        key = self.rsa.importKey(der)
        self.assertEqual(key.n, 17)
        self.assertEqual(key.e, 3)

    def testImportKey12(self):
        """Verify import of RSAPublicKey DER SEQUENCE, encoded with PEM"""
        der = asn1.DerSequence([17, 3]).encode()
        pem = der2pem(der)
        key = self.rsa.importKey(pem)
        self.assertEqual(key.n, 17)
        self.assertEqual(key.e, 3)

    ###
    def testExportKey1(self):
        key = self.rsa.construct([self.n, self.e, self.d, self.p, self.q, self.pInv])
        derKey = key.exportKey("DER")
        self.assertEqual(derKey, self.rsaKeyDER)

    def testExportKey2(self):
        key = self.rsa.construct([self.n, self.e])
        derKey = key.exportKey("DER")
        self.assertEqual(derKey, self.rsaPublicKeyDER)

    def testExportKey3(self):
        key = self.rsa.construct([self.n, self.e, self.d, self.p, self.q, self.pInv])
        pemKey = key.exportKey("PEM")
        self.assertEqual(pemKey, b(self.rsaKeyPEM))

    def testExportKey4(self):
        key = self.rsa.construct([self.n, self.e])
        pemKey = key.exportKey("PEM")
        self.assertEqual(pemKey, b(self.rsaPublicKeyPEM))

    def testExportKey5(self):
        key = self.rsa.construct([self.n, self.e])
        openssh_1 = key.exportKey("OpenSSH").split()
        openssh_2 = self.rsaPublicKeyOpenSSH.split()
        self.assertEqual(openssh_1[0], openssh_2[0])
        self.assertEqual(openssh_1[1], openssh_2[1])

    def testExportKey4(self):
        key = self.rsa.construct([self.n, self.e, self.d, self.p, self.q, self.pInv])
        # Tuple with index #1 is encrypted with 3DES
        t = map(b,self.rsaKeyEncryptedPEM[1])
        # Force the salt being used when exporting
        key._randfunc = lambda N: (t[2]*divmod(N+len(t[2]),len(t[2]))[0])[:N]
        pemKey = key.exportKey("PEM", t[0])
        self.assertEqual(pemKey, t[1])

    def testExportKey5(self):
        key = self.rsa.construct([self.n, self.e, self.d, self.p, self.q, self.pInv])
        derKey = key.exportKey("DER", pkcs=8)
        self.assertEqual(derKey, self.rsaKeyDER8)

    def testExportKey6(self):
        key = self.rsa.construct([self.n, self.e, self.d, self.p, self.q, self.pInv])
        pemKey = key.exportKey("PEM", pkcs=8)
        self.assertEqual(pemKey, b(self.rsaKeyPEM8))

class ImportKeyTestsSlow(ImportKeyTests):
    def setUp(self):
        self.rsa = RSA.RSAImplementation(use_fast_math=0)

class ImportKeyTestsFast(ImportKeyTests):
    def setUp(self):
        self.rsa = RSA.RSAImplementation(use_fast_math=1)

if __name__ == '__main__':
    unittest.main()

def get_tests(config={}):
    tests = []
    try:
        from Crypto.PublicKey import _fastmath
        tests += list_test_cases(ImportKeyTestsFast)
    except ImportError:
        pass
    tests += list_test_cases(ImportKeyTestsSlow)
    return tests

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
