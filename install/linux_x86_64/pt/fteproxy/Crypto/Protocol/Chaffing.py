#
#  Chaffing.py : chaffing & winnowing support
#
# Part of the Python Cryptography Toolkit
#
# Written by Andrew M. Kuchling, Barry A. Warsaw, and others
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
"""This file implements the chaffing algorithm.

Winnowing and chaffing is a technique for enhancing privacy without requiring
strong encryption.  In short, the technique takes a set of authenticated
message blocks (the wheat) and adds a number of chaff blocks which have
randomly chosen data and MAC fields.  This means that to an adversary, the
chaff blocks look as valid as the wheat blocks, and so the authentication
would have to be performed on every block.  By tailoring the number of chaff
blocks added to the message, the sender can make breaking the message
computationally infeasible.  There are many other interesting properties of
the winnow/chaff technique.

For example, say Alice is sending a message to Bob.  She packetizes the
message and performs an all-or-nothing transformation on the packets.  Then
she authenticates each packet with a message authentication code (MAC).  The
MAC is a hash of the data packet, and there is a secret key which she must
share with Bob (key distribution is an exercise left to the reader).  She then
adds a serial number to each packet, and sends the packets to Bob.

Bob receives the packets, and using the shared secret authentication key,
authenticates the MACs for each packet.  Those packets that have bad MACs are
simply discarded.  The remainder are sorted by serial number, and passed
through the reverse all-or-nothing transform.  The transform means that an
eavesdropper (say Eve) must acquire all the packets before any of the data can
be read.  If even one packet is missing, the data is useless.

There's one twist: by adding chaff packets, Alice and Bob can make Eve's job
much harder, since Eve now has to break the shared secret key, or try every
combination of wheat and chaff packet to read any of the message.  The cool
thing is that Bob doesn't need to add any additional code; the chaff packets
are already filtered out because their MACs don't match (in all likelihood --
since the data and MACs for the chaff packets are randomly chosen it is
possible, but very unlikely that a chaff MAC will match the chaff data).  And
Alice need not even be the party adding the chaff!  She could be completely
unaware that a third party, say Charles, is adding chaff packets to her
messages as they are transmitted.

For more information on winnowing and chaffing see this paper:

Ronald L. Rivest, "Chaffing and Winnowing: Confidentiality without Encryption"
http://theory.lcs.mit.edu/~rivest/chaffing.txt

"""

__revision__ = "$Id$"

from Crypto.Util.number import bytes_to_long

class Chaff:
    """Class implementing the chaff adding algorithm.

    Methods for subclasses:

            _randnum(size):
                Returns a randomly generated number with a byte-length equal
                to size.  Subclasses can use this to implement better random
                data and MAC generating algorithms.  The default algorithm is
                probably not very cryptographically secure.  It is most
                important that the chaff data does not contain any patterns
                that can be used to discern it from wheat data without running
                the MAC.

    """

    def __init__(self, factor=1.0, blocksper=1):
        """Chaff(factor:float, blocksper:int)

        factor is the number of message blocks to add chaff to,
        expressed as a percentage between 0.0 and 1.0.  blocksper is
        the number of chaff blocks to include for each block being
        chaffed.  Thus the defaults add one chaff block to every
        message block.  By changing the defaults, you can adjust how
        computationally difficult it could be for an adversary to
        brute-force crack the message.  The difficulty is expressed
        as:

            pow(blocksper, int(factor * number-of-blocks))

        For ease of implementation, when factor < 1.0, only the first
        int(factor*number-of-blocks) message blocks are chaffed.
        """

        if not (0.0<=factor<=1.0):
            raise ValueError, "'factor' must be between 0.0 and 1.0"
        if blocksper < 0:
            raise ValueError, "'blocksper' must be zero or more"

        self.__factor = factor
        self.__blocksper = blocksper


    def chaff(self, blocks):
        """chaff( [(serial-number:int, data:string, MAC:string)] )
        : [(int, string, string)]

        Add chaff to message blocks.  blocks is a list of 3-tuples of the
        form (serial-number, data, MAC).

        Chaff is created by choosing a random number of the same
        byte-length as data, and another random number of the same
        byte-length as MAC.  The message block's serial number is
        placed on the chaff block and all the packet's chaff blocks
        are randomly interspersed with the single wheat block.  This
        method then returns a list of 3-tuples of the same form.
        Chaffed blocks will contain multiple instances of 3-tuples
        with the same serial number, but the only way to figure out
        which blocks are wheat and which are chaff is to perform the
        MAC hash and compare values.
        """

        chaffedblocks = []

        # count is the number of blocks to add chaff to.  blocksper is the
        # number of chaff blocks to add per message block that is being
        # chaffed.
        count = len(blocks) * self.__factor
        blocksper = range(self.__blocksper)
        for i, wheat in zip(range(len(blocks)), blocks):
            # it shouldn't matter which of the n blocks we add chaff to, so for
            # ease of implementation, we'll just add them to the first count
            # blocks
            if i < count:
                serial, data, mac = wheat
                datasize = len(data)
                macsize = len(mac)
                addwheat = 1
                # add chaff to this block
                for j in blocksper:
                    import sys
                    chaffdata = self._randnum(datasize)
                    chaffmac = self._randnum(macsize)
                    chaff = (serial, chaffdata, chaffmac)
                    # mix up the order, if the 5th bit is on then put the
                    # wheat on the list
                    if addwheat and bytes_to_long(self._randnum(16)) & 0x40:
                        chaffedblocks.append(wheat)
                        addwheat = 0
                    chaffedblocks.append(chaff)
                if addwheat:
                    chaffedblocks.append(wheat)
            else:
                # just add the wheat
                chaffedblocks.append(wheat)
        return chaffedblocks

    def _randnum(self, size):
        from Crypto import Random
        return Random.new().read(size)


if __name__ == '__main__':
    text = """\
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
    print 'Original text:\n=========='
    print text
    print '=========='

    # first transform the text into packets
    blocks = [] ; size = 40
    for i in range(0, len(text), size):
        blocks.append( text[i:i+size] )

    # now get MACs for all the text blocks.  The key is obvious...
    print 'Calculating MACs...'
    from Crypto.Hash import HMAC, SHA
    key = 'Jefferson'
    macs = [HMAC.new(key, block, digestmod=SHA).digest()
            for block in blocks]

    assert len(blocks) == len(macs)

    # put these into a form acceptable as input to the chaffing procedure
    source = []
    m = zip(range(len(blocks)), blocks, macs)
    print m
    for i, data, mac in m:
        source.append((i, data, mac))

    # now chaff these
    print 'Adding chaff...'
    c = Chaff(factor=0.5, blocksper=2)
    chaffed = c.chaff(source)

    from base64 import encodestring

    # print the chaffed message blocks.  meanwhile, separate the wheat from
    # the chaff

    wheat = []
    print 'chaffed message blocks:'
    for i, data, mac in chaffed:
        # do the authentication
        h = HMAC.new(key, data, digestmod=SHA)
        pmac = h.digest()
        if pmac == mac:
            tag = '-->'
            wheat.append(data)
        else:
            tag = '   '
        # base64 adds a trailing newline
        print tag, '%3d' % i, \
              repr(data), encodestring(mac)[:-1]

    # now decode the message packets and check it against the original text
    print 'Undigesting wheat...'
    # PY3K: This is meant to be text, do not change to bytes (data)
    newtext = "".join(wheat)
    if newtext == text:
        print 'They match!'
    else:
        print 'They differ!'
