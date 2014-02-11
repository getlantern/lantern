# -*- coding: utf-8 -*-
#
#  SelfTest/Random/Fortuna/test_SHAd256.py: Self-test for the SHAd256 hash function
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

"""Self-test suite for Crypto.Random.Fortuna.SHAd256"""

__revision__ = "$Id$"
from Crypto.Util.py3compat import *

# This is a list of (expected_result, input[, description]) tuples.
test_data = [
    # I could not find any test vectors for SHAd256, so I made these vectors by
    # feeding some sample data into several plain SHA256 implementations
    # (including OpenSSL, the "sha256sum" tool, and this implementation).
    # This is a subset of the resulting test vectors.  The complete list can be
    # found at: http://www.dlitz.net/crypto/shad256-test-vectors/
    ('5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456',
        '', "'' (empty string)"),
    ('4f8b42c22dd3729b519ba6f68d2da7cc5b2d606d05daed5ad5128cc03e6c6358',
        'abc'),
    ('0cffe17f68954dac3a84fb1458bd5ec99209449749b2b308b7cb55812f9563af',
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')
]

def get_tests(config={}):
    from Crypto.Random.Fortuna import SHAd256
    from Crypto.SelfTest.Hash.common import make_hash_tests
    return make_hash_tests(SHAd256, "SHAd256", test_data, 32)

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
