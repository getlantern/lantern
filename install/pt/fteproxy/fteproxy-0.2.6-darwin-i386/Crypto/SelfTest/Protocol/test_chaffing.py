#
# Test script for Crypto.Protocol.Chaffing
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
from Crypto.Protocol import Chaffing

text = """\
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
"""

class ChaffingTest (unittest.TestCase):

    def runTest(self):
        "Simple tests of chaffing and winnowing"
	# Test constructors
        Chaffing.Chaff()
        Chaffing.Chaff(0.5, 1)
        self.assertRaises(ValueError, Chaffing.Chaff, factor=-1)
        self.assertRaises(ValueError, Chaffing.Chaff, blocksper=-1)

        data = [(1, 'data1', 'data1'), (2, 'data2', 'data2')]
        c = Chaffing.Chaff(1.0, 1)
        c.chaff(data)
        chaff = c.chaff(data)
        self.assertEqual(len(chaff), 4)

        c = Chaffing.Chaff(0.0, 1)
        chaff = c.chaff(data)
        self.assertEqual(len(chaff), 2)

def get_tests(config={}):
    return [ChaffingTest()]

if __name__ == "__main__":
    unittest.main()
