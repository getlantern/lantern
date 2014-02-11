# -*- coding: utf-8 -*-
#
#  SelfTest/Protocol/test_KDF.py: Self-test for key derivation functions
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

__revision__ = "$Id$"

import unittest
from binascii import unhexlify

from Crypto.SelfTest.st_common import list_test_cases
from Crypto.Hash import SHA as SHA1,HMAC

from Crypto.Protocol.KDF import *

def t2b(t): return unhexlify(b(t))

class PBKDF1_Tests(unittest.TestCase):

    # List of tuples with test data.
    # Each tuple is made up by:
    #       Item #0: a pass phrase
    #       Item #1: salt (8 bytes encoded in hex)
    #       Item #2: output key length
    #       Item #3: iterations to use
    #       Item #4: expected result (encoded in hex)
    _testData = (
            # From http://www.di-mgt.com.au/cryptoKDFs.html#examplespbkdf
            ("password","78578E5A5D63CB06",16,1000,"DC19847E05C64D2FAF10EBFB4A3D2A20"),
    )
    
    def test1(self):
        v = self._testData[0]
        res = PBKDF1(v[0], t2b(v[1]), v[2], v[3], SHA1)
        self.assertEqual(res, t2b(v[4]))

class PBKDF2_Tests(unittest.TestCase):

    # List of tuples with test data.
    # Each tuple is made up by:
    #       Item #0: a pass phrase
    #       Item #1: salt (encoded in hex)
    #       Item #2: output key length
    #       Item #3: iterations to use
    #       Item #4: expected result (encoded in hex)
    _testData = (
            # From http://www.di-mgt.com.au/cryptoKDFs.html#examplespbkdf
            ("password","78578E5A5D63CB06",24,2048,"BFDE6BE94DF7E11DD409BCE20A0255EC327CB936FFE93643"),
            # From RFC 6050
            ("password","73616c74", 20, 1,          "0c60c80f961f0e71f3a9b524af6012062fe037a6"),
            ("password","73616c74", 20, 2,          "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957"),
            ("password","73616c74", 20, 4096,       "4b007901b765489abead49d926f721d065a429c1"),
            ("passwordPASSWORDpassword","73616c7453414c5473616c7453414c5473616c7453414c5473616c7453414c5473616c74",
                                    25, 4096,       "3d2eec4fe41c849b80c8d83662c0e44a8b291a964cf2f07038"),
            ( 'pass\x00word',"7361006c74",16,4096,  "56fa6aa75548099dcc37d7f03425e0c3"),
    )
    
    def test1(self):
        # Test only for HMAC-SHA1 as PRF

        def prf(p,s):
            return HMAC.new(p,s,SHA1).digest()

        for i in xrange(len(self._testData)):
            v = self._testData[i]
            res  = PBKDF2(v[0], t2b(v[1]), v[2], v[3])
            res2 = PBKDF2(v[0], t2b(v[1]), v[2], v[3], prf)
            self.assertEqual(res, t2b(v[4]))
            self.assertEqual(res, res2)

def get_tests(config={}):
    tests = []
    tests += list_test_cases(PBKDF1_Tests)
    tests += list_test_cases(PBKDF2_Tests)
    return tests

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4
