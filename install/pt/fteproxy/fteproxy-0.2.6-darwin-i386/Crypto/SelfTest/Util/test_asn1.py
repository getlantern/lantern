# -*- coding: utf-8 -*-
#
#  SelfTest/Util/test_asn.py: Self-test for the Crypto.Util.asn1 module
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

"""Self-tests for Crypto.Util.asn1"""

__revision__ = "$Id$"

import unittest
import sys

from Crypto.Util.py3compat import *
from Crypto.Util.asn1 import DerSequence, DerObject

class DerObjectTests(unittest.TestCase):

	def testObjEncode1(self):
		# No payload
		der = DerObject(b('\x33'))
		self.assertEquals(der.encode(), b('\x33\x00'))
		# Small payload
		der.payload = b('\x45')
		self.assertEquals(der.encode(), b('\x33\x01\x45'))
		# Invariant
		self.assertEquals(der.encode(), b('\x33\x01\x45'))
		# Initialize with numerical tag
		der = DerObject(b(0x33))
		der.payload = b('\x45')
		self.assertEquals(der.encode(), b('\x33\x01\x45'))

	def testObjEncode2(self):
		# Known types
		der = DerObject('SEQUENCE')
		self.assertEquals(der.encode(), b('\x30\x00'))
		der = DerObject('BIT STRING')
		self.assertEquals(der.encode(), b('\x03\x00'))
		
	def testObjEncode3(self):
		# Long payload
		der = DerObject(b('\x34'))
		der.payload = b("0")*128
		self.assertEquals(der.encode(), b('\x34\x81\x80' + "0"*128))		

	def testObjDecode1(self):
		# Decode short payload
		der = DerObject()
		der.decode(b('\x20\x02\x01\x02'))
		self.assertEquals(der.payload, b("\x01\x02"))
		self.assertEquals(der.typeTag, 0x20)

	def testObjDecode2(self):
		# Decode short payload
		der = DerObject()
		der.decode(b('\x22\x81\x80' + "1"*128))
		self.assertEquals(der.payload, b("1")*128)
		self.assertEquals(der.typeTag, 0x22)

class DerSequenceTests(unittest.TestCase):

	def testEncode1(self):
		# Empty sequence
		der = DerSequence()
		self.assertEquals(der.encode(), b('0\x00'))
		self.failIf(der.hasOnlyInts())
		# One single-byte integer (zero)
		der.append(0)
		self.assertEquals(der.encode(), b('0\x03\x02\x01\x00'))
		self.failUnless(der.hasOnlyInts())
		# Invariant
		self.assertEquals(der.encode(), b('0\x03\x02\x01\x00'))

	def testEncode2(self):
		# One single-byte integer (non-zero)
		der = DerSequence()
		der.append(127)
		self.assertEquals(der.encode(), b('0\x03\x02\x01\x7f'))
		# Indexing
		der[0] = 1
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],1)
		self.assertEquals(der[-1],1)
		self.assertEquals(der.encode(), b('0\x03\x02\x01\x01'))
		#
		der[:] = [1]
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],1)
		self.assertEquals(der.encode(), b('0\x03\x02\x01\x01'))
	
	def testEncode3(self):
		# One multi-byte integer (non-zero)
		der = DerSequence()
		der.append(0x180L)
		self.assertEquals(der.encode(), b('0\x04\x02\x02\x01\x80'))
	
	def testEncode4(self):
		# One very long integer
		der = DerSequence()
		der.append(2**2048)
		self.assertEquals(der.encode(), b('0\x82\x01\x05')+
		b('\x02\x82\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
        b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00'))

	def testEncode5(self):
		# One single-byte integer (looks negative)
		der = DerSequence()
		der.append(0xFFL)
		self.assertEquals(der.encode(), b('0\x04\x02\x02\x00\xff'))
	
	def testEncode6(self):
		# Two integers
		der = DerSequence()
		der.append(0x180L)
		der.append(0xFFL)
		self.assertEquals(der.encode(), b('0\x08\x02\x02\x01\x80\x02\x02\x00\xff'))
		self.failUnless(der.hasOnlyInts())
		#
		der.append(0x01)
		der[1:] = [9,8]
		self.assertEquals(len(der),3)
		self.assertEqual(der[1:],[9,8])
		self.assertEqual(der[1:-1],[9])
		self.assertEquals(der.encode(), b('0\x0A\x02\x02\x01\x80\x02\x01\x09\x02\x01\x08'))

	def testEncode6(self):
		# One integer and another type (no matter what it is)
		der = DerSequence()
		der.append(0x180L)
		der.append(b('\x00\x02\x00\x00'))
		self.assertEquals(der.encode(), b('0\x08\x02\x02\x01\x80\x00\x02\x00\x00'))
		self.failIf(der.hasOnlyInts())

	####

	def testDecode1(self):
		# Empty sequence
		der = DerSequence()
		der.decode(b('0\x00'))
		self.assertEquals(len(der),0)
		# One single-byte integer (zero)
		der.decode(b('0\x03\x02\x01\x00'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],0)
		# Invariant
		der.decode(b('0\x03\x02\x01\x00'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],0)

	def testDecode2(self):
		# One single-byte integer (non-zero)
		der = DerSequence()
		der.decode(b('0\x03\x02\x01\x7f'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],127)
	
	def testDecode3(self):
		# One multi-byte integer (non-zero)
		der = DerSequence()
		der.decode(b('0\x04\x02\x02\x01\x80'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],0x180L)

	def testDecode4(self):
		# One very long integer
		der = DerSequence()
		der.decode(b('0\x82\x01\x05')+
		b('\x02\x82\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
        b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')+
		b('\x00\x00\x00\x00\x00\x00\x00\x00\x00'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],2**2048)

	def testDecode5(self):
		# One single-byte integer (looks negative)
		der = DerSequence()
		der.decode(b('0\x04\x02\x02\x00\xff'))
		self.assertEquals(len(der),1)
		self.assertEquals(der[0],0xFFL)

	def testDecode6(self):
		# Two integers
		der = DerSequence()
		der.decode(b('0\x08\x02\x02\x01\x80\x02\x02\x00\xff'))
		self.assertEquals(len(der),2)
		self.assertEquals(der[0],0x180L)
		self.assertEquals(der[1],0xFFL)

	def testDecode7(self):
		# One integer and 2 other types
		der = DerSequence()
		der.decode(b('0\x0A\x02\x02\x01\x80\x24\x02\xb6\x63\x12\x00'))
		self.assertEquals(len(der),3)
		self.assertEquals(der[0],0x180L)
		self.assertEquals(der[1],b('\x24\x02\xb6\x63'))
		self.assertEquals(der[2],b('\x12\x00'))

	def testDecode8(self):
		# Only 2 other types
		der = DerSequence()
		der.decode(b('0\x06\x24\x02\xb6\x63\x12\x00'))
		self.assertEquals(len(der),2)
		self.assertEquals(der[0],b('\x24\x02\xb6\x63'))
		self.assertEquals(der[1],b('\x12\x00'))

	def testErrDecode1(self):
		# Not a sequence
		der = DerSequence()
		self.assertRaises(ValueError, der.decode, b(''))
		self.assertRaises(ValueError, der.decode, b('\x00'))
		self.assertRaises(ValueError, der.decode, b('\x30'))

	def testErrDecode2(self):
		# Wrong payload type
		der = DerSequence()
		self.assertRaises(ValueError, der.decode, b('\x30\x00\x00'), True)

	def testErrDecode3(self):
		# Wrong length format
		der = DerSequence()
		self.assertRaises(ValueError, der.decode, b('\x30\x04\x02\x01\x01\x00'))
		self.assertRaises(ValueError, der.decode, b('\x30\x81\x03\x02\x01\x01'))
		self.assertRaises(ValueError, der.decode, b('\x30\x04\x02\x81\x01\x01'))

	def testErrDecode4(self):
		# Wrong integer format
		der = DerSequence()
		# Multi-byte encoding for zero
		#self.assertRaises(ValueError, der.decode, '\x30\x04\x02\x02\x00\x00')
		# Negative integer
		self.assertRaises(ValueError, der.decode, b('\x30\x04\x02\x01\xFF'))

def get_tests(config={}):
    from Crypto.SelfTest.st_common import list_test_cases
    listTests = []
    listTests += list_test_cases(DerObjectTests)
    listTests += list_test_cases(DerSequenceTests)
    return listTests

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
