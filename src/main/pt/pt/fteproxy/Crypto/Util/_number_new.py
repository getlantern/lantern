# -*- coding: ascii -*-
#
#  Util/_number_new.py : utility functions
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

## NOTE: Do not import this module directly.  Import these functions from Crypto.Util.number.

__revision__ = "$Id$"
__all__ = ['ceil_shift', 'ceil_div', 'floor_div', 'exact_log2', 'exact_div']

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *

def ceil_shift(n, b):
    """Return ceil(n / 2**b) without performing any floating-point or division operations.

    This is done by right-shifting n by b bits and incrementing the result by 1
    if any '1' bits were shifted out.
    """
    if not isinstance(n, (int, long)) or not isinstance(b, (int, long)):
        raise TypeError("unsupported operand type(s): %r and %r" % (type(n).__name__, type(b).__name__))

    assert n >= 0 and b >= 0    # I haven't tested or even thought about negative values
    mask = (1L << b) - 1
    if n & mask:
        return (n >> b) + 1
    else:
        return n >> b

def ceil_div(a, b):
    """Return ceil(a / b) without performing any floating-point operations."""

    if not isinstance(a, (int, long)) or not isinstance(b, (int, long)):
        raise TypeError("unsupported operand type(s): %r and %r" % (type(a).__name__, type(b).__name__))

    (q, r) = divmod(a, b)
    if r:
        return q + 1
    else:
        return q

def floor_div(a, b):
    if not isinstance(a, (int, long)) or not isinstance(b, (int, long)):
        raise TypeError("unsupported operand type(s): %r and %r" % (type(a).__name__, type(b).__name__))

    (q, r) = divmod(a, b)
    return q

def exact_log2(num):
    """Find and return an integer i >= 0 such that num == 2**i.

    If no such integer exists, this function raises ValueError.
    """

    if not isinstance(num, (int, long)):
        raise TypeError("unsupported operand type: %r" % (type(num).__name__,))

    n = long(num)
    if n <= 0:
        raise ValueError("cannot compute logarithm of non-positive number")

    i = 0
    while n != 0:
        if (n & 1) and n != 1:
            raise ValueError("No solution could be found")
        i += 1
        n >>= 1
    i -= 1

    assert num == (1L << i)
    return i

def exact_div(p, d, allow_divzero=False):
    """Find and return an integer n such that p == n * d

    If no such integer exists, this function raises ValueError.

    Both operands must be integers.

    If the second operand is zero, this function will raise ZeroDivisionError
    unless allow_divzero is true (default: False).
    """

    if not isinstance(p, (int, long)) or not isinstance(d, (int, long)):
        raise TypeError("unsupported operand type(s): %r and %r" % (type(p).__name__, type(d).__name__))

    if d == 0 and allow_divzero:
        n = 0
        if p != n * d:
            raise ValueError("No solution could be found")
    else:
        (n, r) = divmod(p, d)
        if r != 0:
            raise ValueError("No solution could be found")

    assert p == n * d
    return n

# vim:set ts=4 sw=4 sts=4 expandtab:
