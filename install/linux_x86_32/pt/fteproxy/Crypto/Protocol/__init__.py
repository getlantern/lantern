# -*- coding: utf-8 -*-
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

"""Cryptographic protocols

Implements various cryptographic protocols.  (Don't expect to find
network protocols here.)

Crypto.Protocol.AllOrNothing
 Transforms a message into a set of message blocks, such that the blocks
 can be recombined to get the message back.

Crypto.Protocol.Chaffing
 Takes a set of authenticated message blocks (the wheat) and adds a number
 of randomly generated blocks (the chaff).

Crypto.Protocol.KDF
 A collection of standard key derivation functions.

:undocumented: __revision__
"""

__all__ = ['AllOrNothing', 'Chaffing', 'KDF']
__revision__ = "$Id$"
