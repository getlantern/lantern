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

"""Public-key encryption and signature algorithms.

Public-key encryption uses two different keys, one for encryption and
one for decryption.  The encryption key can be made public, and the
decryption key is kept private.  Many public-key algorithms can also
be used to sign messages, and some can *only* be used for signatures.

========================  =============================================
Module                    Description
========================  =============================================
Crypto.PublicKey.DSA      Digital Signature Algorithm (Signature only)
Crypto.PublicKey.ElGamal  (Signing and encryption)
Crypto.PublicKey.RSA      (Signing, encryption, and blinding)
========================  =============================================

:undocumented: _DSA, _RSA, _fastmath, _slowmath, pubkey
"""

__all__ = ['RSA', 'DSA', 'ElGamal']
__revision__ = "$Id$"

