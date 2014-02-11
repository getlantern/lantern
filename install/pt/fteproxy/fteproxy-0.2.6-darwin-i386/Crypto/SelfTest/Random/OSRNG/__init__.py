# -*- coding: utf-8 -*-
#
#  SelfTest/Random/OSRNG/__init__.py: Self-test for OSRNG modules
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

"""Self-test for Crypto.Random.OSRNG package"""

__revision__ = "$Id$"

import os

def get_tests(config={}):
    tests = []
    if os.name == 'nt':
        from Crypto.SelfTest.Random.OSRNG import test_nt;        tests += test_nt.get_tests(config=config)
        from Crypto.SelfTest.Random.OSRNG import test_winrandom; tests += test_winrandom.get_tests(config=config)
    elif os.name == 'posix':
        from Crypto.SelfTest.Random.OSRNG import test_posix;     tests += test_posix.get_tests(config=config)
    if hasattr(os, 'urandom'):
        from Crypto.SelfTest.Random.OSRNG import test_fallback;      tests += test_fallback.get_tests(config=config)
    from Crypto.SelfTest.Random.OSRNG import test_generic;       tests += test_generic.get_tests(config=config)
    return tests

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')


# vim:set ts=4 sw=4 sts=4 expandtab:
