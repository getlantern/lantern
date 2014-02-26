# -*- coding: ascii -*-
#
#  pct_warnings.py : PyCrypto warnings file
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

#
# Base classes.  All our warnings inherit from one of these in order to allow
# the user to specifically filter them.
#

class CryptoWarning(Warning):
    """Base class for PyCrypto warnings"""

class CryptoDeprecationWarning(DeprecationWarning, CryptoWarning):
    """Base PyCrypto DeprecationWarning class"""

class CryptoRuntimeWarning(RuntimeWarning, CryptoWarning):
    """Base PyCrypto RuntimeWarning class"""

#
# Warnings that we might actually use
#

class RandomPool_DeprecationWarning(CryptoDeprecationWarning):
    """Issued when Crypto.Util.randpool.RandomPool is instantiated."""

class ClockRewindWarning(CryptoRuntimeWarning):
    """Warning for when the system clock moves backwards."""

class GetRandomNumber_DeprecationWarning(CryptoDeprecationWarning):
    """Issued when Crypto.Util.number.getRandomNumber is invoked."""

class PowmInsecureWarning(CryptoRuntimeWarning):
    """Warning for when _fastmath is built without mpz_powm_sec"""

# By default, we want this warning to be shown every time we compensate for
# clock rewinding.
import warnings as _warnings
_warnings.filterwarnings('always', category=ClockRewindWarning, append=1)

# vim:set ts=4 sw=4 sts=4 expandtab:
