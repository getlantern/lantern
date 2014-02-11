# -*- coding: utf-8 -*-
#
#  SelfTest/Hash/HMAC.py: Self-test for the HMAC module
#
# Written in 2008 by Dwayne C. Litzenberger <dlitz@dlitz.net>
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

"""Self-test suite for Crypto.Hash.HMAC"""

__revision__ = "$Id$"

from common import dict     # For compatibility with Python 2.1 and 2.2
from Crypto.Util.py3compat import *

# This is a list of (key, data, results, description) tuples.
test_data = [
    ## Test vectors from RFC 2202 ##
    # Test that the default hashmod is MD5
    ('0b' * 16,
        '4869205468657265',
        dict(default='9294727a3638bb1c13f48ef8158bfc9d'),
        'default-is-MD5'),

    # Test case 1 (MD5)
    ('0b' * 16,
        '4869205468657265',
        dict(MD5='9294727a3638bb1c13f48ef8158bfc9d'),
        'RFC 2202 #1-MD5 (HMAC-MD5)'),

    # Test case 1 (SHA1)
    ('0b' * 20,
        '4869205468657265',
        dict(SHA1='b617318655057264e28bc0b6fb378c8ef146be00'),
        'RFC 2202 #1-SHA1 (HMAC-SHA1)'),

    # Test case 2
    ('4a656665',
        '7768617420646f2079612077616e7420666f72206e6f7468696e673f',
        dict(MD5='750c783e6ab0b503eaa86e310a5db738',
            SHA1='effcdf6ae5eb2fa2d27416d5f184df9c259a7c79'),
        'RFC 2202 #2 (HMAC-MD5/SHA1)'),

    # Test case 3 (MD5)
    ('aa' * 16,
        'dd' * 50,
        dict(MD5='56be34521d144c88dbb8c733f0e8b3f6'),
        'RFC 2202 #3-MD5 (HMAC-MD5)'),

    # Test case 3 (SHA1)
    ('aa' * 20,
        'dd' * 50,
        dict(SHA1='125d7342b9ac11cd91a39af48aa17b4f63f175d3'),
        'RFC 2202 #3-SHA1 (HMAC-SHA1)'),

    # Test case 4
    ('0102030405060708090a0b0c0d0e0f10111213141516171819',
        'cd' * 50,
        dict(MD5='697eaf0aca3a3aea3a75164746ffaa79',
            SHA1='4c9007f4026250c6bc8414f9bf50c86c2d7235da'),
        'RFC 2202 #4 (HMAC-MD5/SHA1)'),

    # Test case 5 (MD5)
    ('0c' * 16,
        '546573742057697468205472756e636174696f6e',
        dict(MD5='56461ef2342edc00f9bab995690efd4c'),
        'RFC 2202 #5-MD5 (HMAC-MD5)'),

    # Test case 5 (SHA1)
    # NB: We do not implement hash truncation, so we only test the full hash here.
    ('0c' * 20,
        '546573742057697468205472756e636174696f6e',
        dict(SHA1='4c1a03424b55e07fe7f27be1d58bb9324a9a5a04'),
        'RFC 2202 #5-SHA1 (HMAC-SHA1)'),

    # Test case 6
    ('aa' * 80,
        '54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a'
        + '65204b6579202d2048617368204b6579204669727374',
        dict(MD5='6b1ab7fe4bd7bf8f0b62e6ce61b9d0cd',
            SHA1='aa4ae5e15272d00e95705637ce8a3b55ed402112'),
        'RFC 2202 #6 (HMAC-MD5/SHA1)'),

    # Test case 7
    ('aa' * 80,
        '54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a'
        + '65204b657920616e64204c6172676572205468616e204f6e6520426c6f636b2d'
        + '53697a652044617461',
        dict(MD5='6f630fad67cda0ee1fb1f562db3aa53e',
            SHA1='e8e99d0f45237d786d6bbaa7965c7808bbff1a91'),
        'RFC 2202 #7 (HMAC-MD5/SHA1)'),

    ## Test vectors from RFC 4231 ##
    # 4.2. Test Case 1
    ('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b',
        '4869205468657265',
        dict(SHA256='''
            b0344c61d8db38535ca8afceaf0bf12b
            881dc200c9833da726e9376c2e32cff7
        '''),
        'RFC 4231 #1 (HMAC-SHA256)'),

    # 4.3. Test Case 2 - Test with a key shorter than the length of the HMAC
    # output.
    ('4a656665',
        '7768617420646f2079612077616e7420666f72206e6f7468696e673f',
        dict(SHA256='''
            5bdcc146bf60754e6a042426089575c7
            5a003f089d2739839dec58b964ec3843
        '''),
        'RFC 4231 #2 (HMAC-SHA256)'),

    # 4.4. Test Case 3 - Test with a combined length of key and data that is
    # larger than 64 bytes (= block-size of SHA-224 and SHA-256).
    ('aa' * 20,
        'dd' * 50,
        dict(SHA256='''
            773ea91e36800e46854db8ebd09181a7
            2959098b3ef8c122d9635514ced565fe
        '''),
        'RFC 4231 #3 (HMAC-SHA256)'),

    # 4.5. Test Case 4 - Test with a combined length of key and data that is
    # larger than 64 bytes (= block-size of SHA-224 and SHA-256).
    ('0102030405060708090a0b0c0d0e0f10111213141516171819',
        'cd' * 50,
        dict(SHA256='''
            82558a389a443c0ea4cc819899f2083a
            85f0faa3e578f8077a2e3ff46729665b
        '''),
        'RFC 4231 #4 (HMAC-SHA256)'),

    # 4.6. Test Case 5 - Test with a truncation of output to 128 bits.
    #
    # Not included because we do not implement hash truncation.
    #

    # 4.7. Test Case 6 - Test with a key larger than 128 bytes (= block-size of
    # SHA-384 and SHA-512).
    ('aa' * 131,
        '54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a'
        + '65204b6579202d2048617368204b6579204669727374',
        dict(SHA256='''
            60e431591ee0b67f0d8a26aacbf5b77f
            8e0bc6213728c5140546040f0ee37f54
        '''),
        'RFC 4231 #6 (HMAC-SHA256)'),

    # 4.8. Test Case 7 - Test with a key and data that is larger than 128 bytes
    # (= block-size of SHA-384 and SHA-512).
    ('aa' * 131,
        '5468697320697320612074657374207573696e672061206c6172676572207468'
        + '616e20626c6f636b2d73697a65206b657920616e642061206c61726765722074'
        + '68616e20626c6f636b2d73697a6520646174612e20546865206b6579206e6565'
        + '647320746f20626520686173686564206265666f7265206265696e6720757365'
        + '642062792074686520484d414320616c676f726974686d2e',
        dict(SHA256='''
            9b09ffa71b942fcb27635fbcd5b0e944
            bfdc63644f0713938a7f51535c3a35e2
        '''),
        'RFC 4231 #7 (HMAC-SHA256)'),
]

hashlib_test_data = [
    # Test case 8 (SHA224)
    ('4a656665',
        '7768617420646f2079612077616e74'
        + '20666f72206e6f7468696e673f',
        dict(SHA224='a30e01098bc6dbbf45690f3a7e9e6d0f8bbea2a39e6148008fd05e44'),
        'RFC 4634 8.4 SHA224 (HMAC-SHA224)'),

    # Test case 9 (SHA384)
    ('4a656665',
        '7768617420646f2079612077616e74'
        + '20666f72206e6f7468696e673f',
        dict(SHA384='af45d2e376484031617f78d2b58a6b1b9c7ef464f5a01b47e42ec3736322445e8e2240ca5e69e2c78b3239ecfab21649'),
        'RFC 4634 8.4 SHA384 (HMAC-SHA384)'),

   # Test case 10 (SHA512)
    ('4a656665',
        '7768617420646f2079612077616e74'
        + '20666f72206e6f7468696e673f',
        dict(SHA512='164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737'),
        'RFC 4634 8.4 SHA512 (HMAC-SHA512)'),

]

def get_tests(config={}):
    global test_data
    from Crypto.Hash import HMAC, MD5, SHA as SHA1, SHA256
    from common import make_mac_tests
    hashmods = dict(MD5=MD5, SHA1=SHA1, SHA256=SHA256, default=None)
    try:
        from Crypto.Hash import SHA224, SHA384, SHA512
        hashmods.update(dict(SHA224=SHA224, SHA384=SHA384, SHA512=SHA512))
        test_data += hashlib_test_data
    except ImportError:
        import sys
        sys.stderr.write("SelfTest: warning: not testing HMAC-SHA224/384/512 (not available)\n")
    return make_mac_tests(HMAC, "HMAC", test_data, hashmods)

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
