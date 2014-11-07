# -*- coding: utf-8 -*-
#
#  Util/py21compat.py : Compatibility code for Python 2.1
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

"""Compatibility code for Python 2.1

Currently, this just defines:
    - True and False
    - object
    - isinstance
"""

__revision__ = "$Id$"
__all__ = []

import sys
import __builtin__

# 'True' and 'False' aren't defined in Python 2.1.  Define them.
try:
    True, False
except NameError:
    (True, False) = (1, 0)
    __all__ += ['True', 'False']

# New-style classes were introduced in Python 2.2.  Defining "object" in Python
# 2.1 lets us use new-style classes in versions of Python that support them,
# while still maintaining backward compatibility with old-style classes
try:
    object
except NameError:
    class object: pass
    __all__ += ['object']

# Starting with Python 2.2, isinstance allows a tuple for the second argument.
# Also, builtins like "tuple", "list", "str", "unicode", "int", and "long"
# became first-class types, rather than functions.  We want to support
# constructs like:
#   isinstance(x, (int, long))
# So we hack it for Python 2.1.
try:
    isinstance(5, (int, long))
except TypeError:
    __all__ += ['isinstance']
    _builtin_type_map = {
        tuple: type(()),
        list: type([]),
        str: type(""),
        unicode: type(u""),
        int: type(0),
        long: type(0L),
    }
    def isinstance(obj, t):
        if not __builtin__.isinstance(t, type(())):
            # t is not a tuple
            return __builtin__.isinstance(obj, _builtin_type_map.get(t, t))
        else:
            # t is a tuple
            for typ in t:
                if __builtin__.isinstance(obj, _builtin_type_map.get(typ, typ)):
                    return True
            return False

# vim:set ts=4 sw=4 sts=4 expandtab:
