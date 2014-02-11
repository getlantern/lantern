# -*- coding: utf-8 -*-
#
#  SelfTest/Signature/test_pkcs1_pss.py: Self-test for PKCS#1 PSS signatures
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
from Crypto import Random
from Crypto.SelfTest.st_common import list_test_cases, a2b_hex, b2a_hex
from Crypto.Hash import *
from Crypto.Signature import PKCS1_PSS as PKCS
from Crypto.Util.py3compat import *

def isStr(s):
        t = ''
        try:
                t += s
        except TypeError:
                return 0
        return 1

def rws(t):
    """Remove white spaces, tabs, and new lines from a string"""
    for c in ['\t', '\n', ' ']:
        t = t.replace(c,'')
    return t

def t2b(t):
    """Convert a text string with bytes in hex form to a byte string"""
    clean = b(rws(t))
    if len(clean)%2 == 1:
        raise ValueError("Even number of characters expected")
    return a2b_hex(clean)

# Helper class to count how many bytes have been requested
# from the key's private RNG, w/o counting those used for blinding
class MyKey:
    def __init__(self, key):
        self._key = key
        self.n = key.n
        self.asked = 0
    def _randfunc(self, N):
        self.asked += N
        return self._key._randfunc(N)
    def sign(self, m):
        return self._key.sign(m)
    def has_private(self):
        return self._key.has_private()
    def decrypt(self, m):
        return self._key.decrypt(m)
    def verify(self, m, p):
        return self._key.verify(m, p)
    def encrypt(self, m, p):
        return self._key.encrypt(m, p)

class PKCS1_PSS_Tests(unittest.TestCase):

        # List of tuples with test data for PKCS#1 PSS
        # Each tuple is made up by:
        #       Item #0: dictionary with RSA key component, or key to import
        #       Item #1: data to hash and sign
        #       Item #2: signature of the data #1, done with the key #0,
        #                and salt #3 after hashing it with #4
        #       Item #3: salt
        #       Item #4: hash object generator

        _testData = (

                #
                # From in pss-vect.txt to be found in
                # ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1-vec.zip
                #
                (
                # Private key
                {
                'n':'''a2 ba 40 ee 07 e3 b2 bd 2f 02 ce 22 7f 36 a1 95
                02 44 86 e4 9c 19 cb 41 bb bd fb ba 98 b2 2b 0e
                57 7c 2e ea ff a2 0d 88 3a 76 e6 5e 39 4c 69 d4
                b3 c0 5a 1e 8f ad da 27 ed b2 a4 2b c0 00 fe 88
                8b 9b 32 c2 2d 15 ad d0 cd 76 b3 e7 93 6e 19 95
                5b 22 0d d1 7d 4e a9 04 b1 ec 10 2b 2e 4d e7 75
                12 22 aa 99 15 10 24 c7 cb 41 cc 5e a2 1d 00 ee
                b4 1f 7c 80 08 34 d2 c6 e0 6b ce 3b ce 7e a9 a5''',
                'e':'''01 00 01''',
                # In the test vector, only p and q were given...
                # d is computed offline as e^{-1} mod (p-1)(q-1)
                'd':'''50e2c3e38d886110288dfc68a9533e7e12e27d2aa56
                d2cdb3fb6efa990bcff29e1d2987fb711962860e7391b1ce01
                ebadb9e812d2fbdfaf25df4ae26110a6d7a26f0b810f54875e
                17dd5c9fb6d641761245b81e79f8c88f0e55a6dcd5f133abd3
                5f8f4ec80adf1bf86277a582894cb6ebcd2162f1c7534f1f49
                47b129151b71'''
                },

                # Data to sign
                '''85 9e ef 2f d7 8a ca 00 30 8b dc 47 11 93 bf 55
                bf 9d 78 db 8f 8a 67 2b 48 46 34 f3 c9 c2 6e 64
                78 ae 10 26 0f e0 dd 8c 08 2e 53 a5 29 3a f2 17
                3c d5 0c 6d 5d 35 4f eb f7 8b 26 02 1c 25 c0 27
                12 e7 8c d4 69 4c 9f 46 97 77 e4 51 e7 f8 e9 e0
                4c d3 73 9c 6b bf ed ae 48 7f b5 56 44 e9 ca 74
                ff 77 a5 3c b7 29 80 2f 6e d4 a5 ff a8 ba 15 98
                90 fc''',
                # Signature
                '''8d aa 62 7d 3d e7 59 5d 63 05 6c 7e c6 59 e5 44
                06 f1 06 10 12 8b aa e8 21 c8 b2 a0 f3 93 6d 54
                dc 3b dc e4 66 89 f6 b7 95 1b b1 8e 84 05 42 76
                97 18 d5 71 5d 21 0d 85 ef bb 59 61 92 03 2c 42
                be 4c 29 97 2c 85 62 75 eb 6d 5a 45 f0 5f 51 87
                6f c6 74 3d ed dd 28 ca ec 9b b3 0e a9 9e 02 c3
                48 82 69 60 4f e4 97 f7 4c cd 7c 7f ca 16 71 89
                71 23 cb d3 0d ef 5d 54 a2 b5 53 6a d9 0a 74 7e''',
                # Salt
                '''e3 b5 d5 d0 02 c1 bc e5 0c 2b 65 ef 88 a1 88 d8
                3b ce 7e 61''',
                # Hash algorithm
                SHA
                ),

                #
                # Example 1.1 to be found in
                # ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1-vec.zip
                #
                (
                # Private key
                {
                'n':'''a5 6e 4a 0e 70 10 17 58 9a 51 87 dc 7e a8 41 d1
                56 f2 ec 0e 36 ad 52 a4 4d fe b1 e6 1f 7a d9 91
                d8 c5 10 56 ff ed b1 62 b4 c0 f2 83 a1 2a 88 a3
                94 df f5 26 ab 72 91 cb b3 07 ce ab fc e0 b1 df
                d5 cd 95 08 09 6d 5b 2b 8b 6d f5 d6 71 ef 63 77
                c0 92 1c b2 3c 27 0a 70 e2 59 8e 6f f8 9d 19 f1
                05 ac c2 d3 f0 cb 35 f2 92 80 e1 38 6b 6f 64 c4
                ef 22 e1 e1 f2 0d 0c e8 cf fb 22 49 bd 9a 21 37''',
                'e':'''01 00 01''',
                'd':'''33 a5 04 2a 90 b2 7d 4f 54 51 ca 9b bb d0 b4 47
                71 a1 01 af 88 43 40 ae f9 88 5f 2a 4b be 92 e8
                94 a7 24 ac 3c 56 8c 8f 97 85 3a d0 7c 02 66 c8
                c6 a3 ca 09 29 f1 e8 f1 12 31 88 44 29 fc 4d 9a
                e5 5f ee 89 6a 10 ce 70 7c 3e d7 e7 34 e4 47 27
                a3 95 74 50 1a 53 26 83 10 9c 2a ba ca ba 28 3c
                31 b4 bd 2f 53 c3 ee 37 e3 52 ce e3 4f 9e 50 3b
                d8 0c 06 22 ad 79 c6 dc ee 88 35 47 c6 a3 b3 25'''
                },
                # Message
                '''cd c8 7d a2 23 d7 86 df 3b 45 e0 bb bc 72 13 26
                d1 ee 2a f8 06 cc 31 54 75 cc 6f 0d 9c 66 e1 b6
                23 71 d4 5c e2 39 2e 1a c9 28 44 c3 10 10 2f 15
                6a 0d 8d 52 c1 f4 c4 0b a3 aa 65 09 57 86 cb 76
                97 57 a6 56 3b a9 58 fe d0 bc c9 84 e8 b5 17 a3
                d5 f5 15 b2 3b 8a 41 e7 4a a8 67 69 3f 90 df b0
                61 a6 e8 6d fa ae e6 44 72 c0 0e 5f 20 94 57 29
                cb eb e7 7f 06 ce 78 e0 8f 40 98 fb a4 1f 9d 61
                93 c0 31 7e 8b 60 d4 b6 08 4a cb 42 d2 9e 38 08
                a3 bc 37 2d 85 e3 31 17 0f cb f7 cc 72 d0 b7 1c
                29 66 48 b3 a4 d1 0f 41 62 95 d0 80 7a a6 25 ca
                b2 74 4f d9 ea 8f d2 23 c4 25 37 02 98 28 bd 16
                be 02 54 6f 13 0f d2 e3 3b 93 6d 26 76 e0 8a ed
                1b 73 31 8b 75 0a 01 67 d0''',
                # Signature
                '''90 74 30 8f b5 98 e9 70 1b 22 94 38 8e 52 f9 71
                fa ac 2b 60 a5 14 5a f1 85 df 52 87 b5 ed 28 87
                e5 7c e7 fd 44 dc 86 34 e4 07 c8 e0 e4 36 0b c2
                26 f3 ec 22 7f 9d 9e 54 63 8e 8d 31 f5 05 12 15
                df 6e bb 9c 2f 95 79 aa 77 59 8a 38 f9 14 b5 b9
                c1 bd 83 c4 e2 f9 f3 82 a0 d0 aa 35 42 ff ee 65
                98 4a 60 1b c6 9e b2 8d eb 27 dc a1 2c 82 c2 d4
                c3 f6 6c d5 00 f1 ff 2b 99 4d 8a 4e 30 cb b3 3c''',
                # Salt
                '''de e9 59 c7 e0 64 11 36 14 20 ff 80 18 5e d5 7f
                3e 67 76 af''',
                # Hash
                SHA
                ),

                #
                # Example 1.2 to be found in
                # ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1-vec.zip
                #
                (
                # Private key
                {
                'n':'''a5 6e 4a 0e 70 10 17 58 9a 51 87 dc 7e a8 41 d1
                56 f2 ec 0e 36 ad 52 a4 4d fe b1 e6 1f 7a d9 91
                d8 c5 10 56 ff ed b1 62 b4 c0 f2 83 a1 2a 88 a3
                94 df f5 26 ab 72 91 cb b3 07 ce ab fc e0 b1 df
                d5 cd 95 08 09 6d 5b 2b 8b 6d f5 d6 71 ef 63 77
                c0 92 1c b2 3c 27 0a 70 e2 59 8e 6f f8 9d 19 f1
                05 ac c2 d3 f0 cb 35 f2 92 80 e1 38 6b 6f 64 c4
                ef 22 e1 e1 f2 0d 0c e8 cf fb 22 49 bd 9a 21 37''',
                'e':'''01 00 01''',
                'd':'''33 a5 04 2a 90 b2 7d 4f 54 51 ca 9b bb d0 b4 47
                71 a1 01 af 88 43 40 ae f9 88 5f 2a 4b be 92 e8
                94 a7 24 ac 3c 56 8c 8f 97 85 3a d0 7c 02 66 c8
                c6 a3 ca 09 29 f1 e8 f1 12 31 88 44 29 fc 4d 9a
                e5 5f ee 89 6a 10 ce 70 7c 3e d7 e7 34 e4 47 27
                a3 95 74 50 1a 53 26 83 10 9c 2a ba ca ba 28 3c
                31 b4 bd 2f 53 c3 ee 37 e3 52 ce e3 4f 9e 50 3b
                d8 0c 06 22 ad 79 c6 dc ee 88 35 47 c6 a3 b3 25'''
                },
                # Message
                '''85 13 84 cd fe 81 9c 22 ed 6c 4c cb 30 da eb 5c
                f0 59 bc 8e 11 66 b7 e3 53 0c 4c 23 3e 2b 5f 8f
                71 a1 cc a5 82 d4 3e cc 72 b1 bc a1 6d fc 70 13
                22 6b 9e''',
                # Signature
                '''3e f7 f4 6e 83 1b f9 2b 32 27 41 42 a5 85 ff ce
                fb dc a7 b3 2a e9 0d 10 fb 0f 0c 72 99 84 f0 4e
                f2 9a 9d f0 78 07 75 ce 43 73 9b 97 83 83 90 db
                0a 55 05 e6 3d e9 27 02 8d 9d 29 b2 19 ca 2c 45
                17 83 25 58 a5 5d 69 4a 6d 25 b9 da b6 60 03 c4
                cc cd 90 78 02 19 3b e5 17 0d 26 14 7d 37 b9 35
                90 24 1b e5 1c 25 05 5f 47 ef 62 75 2c fb e2 14
                18 fa fe 98 c2 2c 4d 4d 47 72 4f db 56 69 e8 43''',
                # Salt
                '''ef 28 69 fa 40 c3 46 cb 18 3d ab 3d 7b ff c9 8f
                d5 6d f4 2d''',
                # Hash
                SHA
                ),

                #
                # Example 2.1 to be found in
                # ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1-vec.zip
                #
                (
                # Private key
                {
                'n':'''01 d4 0c 1b cf 97 a6 8a e7 cd bd 8a 7b f3 e3 4f
                a1 9d cc a4 ef 75 a4 74 54 37 5f 94 51 4d 88 fe
                d0 06 fb 82 9f 84 19 ff 87 d6 31 5d a6 8a 1f f3
                a0 93 8e 9a bb 34 64 01 1c 30 3a d9 91 99 cf 0c
                7c 7a 8b 47 7d ce 82 9e 88 44 f6 25 b1 15 e5 e9
                c4 a5 9c f8 f8 11 3b 68 34 33 6a 2f d2 68 9b 47
                2c bb 5e 5c ab e6 74 35 0c 59 b6 c1 7e 17 68 74
                fb 42 f8 fc 3d 17 6a 01 7e dc 61 fd 32 6c 4b 33
                c9''',
                'e':'''01 00 01''',
                'd':'''02 7d 14 7e 46 73 05 73 77 fd 1e a2 01 56 57 72
                17 6a 7d c3 83 58 d3 76 04 56 85 a2 e7 87 c2 3c
                15 57 6b c1 6b 9f 44 44 02 d6 bf c5 d9 8a 3e 88
                ea 13 ef 67 c3 53 ec a0 c0 dd ba 92 55 bd 7b 8b
                b5 0a 64 4a fd fd 1d d5 16 95 b2 52 d2 2e 73 18
                d1 b6 68 7a 1c 10 ff 75 54 5f 3d b0 fe 60 2d 5f
                2b 7f 29 4e 36 01 ea b7 b9 d1 ce cd 76 7f 64 69
                2e 3e 53 6c a2 84 6c b0 c2 dd 48 6a 39 fa 75 b1'''
                },
                # Message
                '''da ba 03 20 66 26 3f ae db 65 98 48 11 52 78 a5
                2c 44 fa a3 a7 6f 37 51 5e d3 36 32 10 72 c4 0a
                9d 9b 53 bc 05 01 40 78 ad f5 20 87 51 46 aa e7
                0f f0 60 22 6d cb 7b 1f 1f c2 7e 93 60''',
                # Signature
                '''01 4c 5b a5 33 83 28 cc c6 e7 a9 0b f1 c0 ab 3f
                d6 06 ff 47 96 d3 c1 2e 4b 63 9e d9 13 6a 5f ec
                6c 16 d8 88 4b dd 99 cf dc 52 14 56 b0 74 2b 73
                68 68 cf 90 de 09 9a db 8d 5f fd 1d ef f3 9b a4
                00 7a b7 46 ce fd b2 2d 7d f0 e2 25 f5 46 27 dc
                65 46 61 31 72 1b 90 af 44 53 63 a8 35 8b 9f 60
                76 42 f7 8f ab 0a b0 f4 3b 71 68 d6 4b ae 70 d8
                82 78 48 d8 ef 1e 42 1c 57 54 dd f4 2c 25 89 b5
                b3''',
                # Salt
                '''57 bf 16 0b cb 02 bb 1d c7 28 0c f0 45 85 30 b7
                d2 83 2f f7''',
                SHA
                ),

                #
                # Example 8.1 to be found in
                # ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1-vec.zip
                #
                (
                # Private key
                {
                'n':'''49 53 70 a1 fb 18 54 3c 16 d3 63 1e 31 63 25 5d
                f6 2b e6 ee e8 90 d5 f2 55 09 e4 f7 78 a8 ea 6f
                bb bc df 85 df f6 4e 0d 97 20 03 ab 36 81 fb ba
                6d d4 1f d5 41 82 9b 2e 58 2d e9 f2 a4 a4 e0 a2
                d0 90 0b ef 47 53 db 3c ee 0e e0 6c 7d fa e8 b1
                d5 3b 59 53 21 8f 9c ce ea 69 5b 08 66 8e de aa
                dc ed 94 63 b1 d7 90 d5 eb f2 7e 91 15 b4 6c ad
                4d 9a 2b 8e fa b0 56 1b 08 10 34 47 39 ad a0 73
                3f''',
                'e':'''01 00 01''',
                'd':'''6c 66 ff e9 89 80 c3 8f cd ea b5 15 98 98 83 61
                65 f4 b4 b8 17 c4 f6 a8 d4 86 ee 4e a9 13 0f e9
                b9 09 2b d1 36 d1 84 f9 5f 50 4a 60 7e ac 56 58
                46 d2 fd d6 59 7a 89 67 c7 39 6e f9 5a 6e ee bb
                45 78 a6 43 96 6d ca 4d 8e e3 de 84 2d e6 32 79
                c6 18 15 9c 1a b5 4a 89 43 7b 6a 61 20 e4 93 0a
                fb 52 a4 ba 6c ed 8a 49 47 ac 64 b3 0a 34 97 cb
                e7 01 c2 d6 26 6d 51 72 19 ad 0e c6 d3 47 db e9'''
                },
                # Message
                '''81 33 2f 4b e6 29 48 41 5e a1 d8 99 79 2e ea cf
                6c 6e 1d b1 da 8b e1 3b 5c ea 41 db 2f ed 46 70
                92 e1 ff 39 89 14 c7 14 25 97 75 f5 95 f8 54 7f
                73 56 92 a5 75 e6 92 3a f7 8f 22 c6 99 7d db 90
                fb 6f 72 d7 bb 0d d5 74 4a 31 de cd 3d c3 68 58
                49 83 6e d3 4a ec 59 63 04 ad 11 84 3c 4f 88 48
                9f 20 97 35 f5 fb 7f da f7 ce c8 ad dc 58 18 16
                8f 88 0a cb f4 90 d5 10 05 b7 a8 e8 4e 43 e5 42
                87 97 75 71 dd 99 ee a4 b1 61 eb 2d f1 f5 10 8f
                12 a4 14 2a 83 32 2e db 05 a7 54 87 a3 43 5c 9a
                78 ce 53 ed 93 bc 55 08 57 d7 a9 fb''',
                # Signature
                '''02 62 ac 25 4b fa 77 f3 c1 ac a2 2c 51 79 f8 f0
                40 42 2b 3c 5b af d4 0a 8f 21 cf 0f a5 a6 67 cc
                d5 99 3d 42 db af b4 09 c5 20 e2 5f ce 2b 1e e1
                e7 16 57 7f 1e fa 17 f3 da 28 05 2f 40 f0 41 9b
                23 10 6d 78 45 aa f0 11 25 b6 98 e7 a4 df e9 2d
                39 67 bb 00 c4 d0 d3 5b a3 55 2a b9 a8 b3 ee f0
                7c 7f ec db c5 42 4a c4 db 1e 20 cb 37 d0 b2 74
                47 69 94 0e a9 07 e1 7f bb ca 67 3b 20 52 23 80
                c5''',
                # Salt
                '''1d 65 49 1d 79 c8 64 b3 73 00 9b e6 f6 f2 46 7b
                ac 4c 78 fa''',
                SHA
                )
        )

        def testSign1(self):
                for i in range(len(self._testData)):
                        # Build the key
                        comps = [ long(rws(self._testData[i][0][x]),16) for x in ('n','e','d') ]
                        key = MyKey(RSA.construct(comps))
                        # Hash function
                        h = self._testData[i][4].new()
                        # Data to sign
                        h.update(t2b(self._testData[i][1]))
                        # Salt
                        test_salt = t2b(self._testData[i][3])
                        key._randfunc = lambda N: test_salt
                        # The real test
                        signer = PKCS.new(key)
                        self.failUnless(signer.can_sign())
                        s = signer.sign(h)
                        self.assertEqual(s, t2b(self._testData[i][2]))

        def testVerify1(self):
               for i in range(len(self._testData)):
                        # Build the key
                        comps = [ long(rws(self._testData[i][0][x]),16) for x in ('n','e') ]
                        key = MyKey(RSA.construct(comps))
                        # Hash function
                        h = self._testData[i][4].new()
                        # Data to sign
                        h.update(t2b(self._testData[i][1]))
                        # Salt
                        test_salt = t2b(self._testData[i][3])
                        # The real test
                        key._randfunc = lambda N: test_salt
                        verifier = PKCS.new(key)
                        self.failIf(verifier.can_sign())
                        result = verifier.verify(h, t2b(self._testData[i][2]))
                        self.failUnless(result)

        def testSignVerify(self):
                        h = SHA.new()
                        h.update(b('blah blah blah'))

                        rng = Random.new().read
                        key = MyKey(RSA.generate(1024,rng))
                         
                        # Helper function to monitor what's request from MGF
                        global mgfcalls
                        def newMGF(seed,maskLen):
                            global mgfcalls
                            mgfcalls += 1
                            return bchr(0x00)*maskLen

                        # Verify that PSS is friendly to all ciphers
                        for hashmod in (MD2,MD5,SHA,SHA224,SHA256,SHA384,RIPEMD):
                            h = hashmod.new()
                            h.update(b('blah blah blah'))

                            # Verify that sign() asks for as many random bytes
                            # as the hash output size
                            key.asked = 0
                            signer = PKCS.new(key)
                            s = signer.sign(h)
                            self.failUnless(signer.verify(h, s))
                            self.assertEqual(key.asked, h.digest_size)

                        h = SHA.new()
                        h.update(b('blah blah blah'))

                        # Verify that sign() uses a different salt length
                        for sLen in (0,3,21):
                            key.asked = 0
                            signer = PKCS.new(key, saltLen=sLen)
                            s = signer.sign(h)
                            self.assertEqual(key.asked, sLen)
                            self.failUnless(signer.verify(h, s))

                        # Verify that sign() uses the custom MGF
                        mgfcalls = 0
                        signer = PKCS.new(key, newMGF)
                        s = signer.sign(h)
                        self.assertEqual(mgfcalls, 1)
                        self.failUnless(signer.verify(h, s))

                        # Verify that sign() does not call the RNG
                        # when salt length is 0, even when a new MGF is provided
                        key.asked = 0
                        mgfcalls = 0
                        signer = PKCS.new(key, newMGF, 0)
                        s = signer.sign(h)
                        self.assertEqual(key.asked,0)
                        self.assertEqual(mgfcalls, 1)
                        self.failUnless(signer.verify(h, s))

def get_tests(config={}):
    tests = []
    tests += list_test_cases(PKCS1_PSS_Tests)
    return tests

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4
