#
# Test script for Crypto.Protocol.AllOrNothing
#
# Part of the Python Cryptography Toolkit
#
# Written by Andrew Kuchling and others
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
from Crypto.Protocol import AllOrNothing
from Crypto.Util.py3compat import *

text = b("""\
When in the Course of human events, it becomes necessary for one people to
dissolve the political bands which have connected them with another, and to
assume among the powers of the earth, the separate and equal station to which
the Laws of Nature and of Nature's God entitle them, a decent respect to the
opinions of mankind requires that they should declare the causes which impel
them to the separation.

We hold these truths to be self-evident, that all men are created equal, that
they are endowed by their Creator with certain unalienable Rights, that among
these are Life, Liberty, and the pursuit of Happiness. That to secure these
rights, Governments are instituted among Men, deriving their just powers from
the consent of the governed. That whenever any Form of Government becomes
destructive of these ends, it is the Right of the People to alter or to
abolish it, and to institute new Government, laying its foundation on such
principles and organizing its powers in such form, as to them shall seem most
likely to effect their Safety and Happiness.
""")

class AllOrNothingTest (unittest.TestCase):

    def runTest(self):
        "Simple test of AllOrNothing"

        from Crypto.Cipher import AES
        import base64

        # The current AllOrNothing will fail
        # every so often. Repeat the test
        # several times to force this.
        for i in range(50):
            x = AllOrNothing.AllOrNothing(AES)

            msgblocks = x.digest(text)
            
            # get a new undigest-only object so there's no leakage
            y = AllOrNothing.AllOrNothing(AES)
            text2 = y.undigest(msgblocks)
            self.assertEqual(text, text2)

def get_tests(config={}):
    return [AllOrNothingTest()]

if __name__ == "__main__":
    unittest.main()
