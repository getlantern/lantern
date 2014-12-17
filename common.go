// package waddell implements a low-latency signaling server that allows peers
// to exchange small messages (up to around 64kB) over TCP.  It is named after
// William B. Waddell, one of the founders of the Pony Express.
//
// Peers are identified by randomly assigned peer ids (type 4 UUIDs), which are
// used to address messages to the peers.  For the scheme to work, peers must
// have some out-of-band mechanism by which they can exchange peer ids.  Note
// that as soon as one peer contacts another via waddell, the 2nd peer will have
// the 1st peer's address and be able to reply using it.
//
// Peers can obtain new ids simply by reconnecting to waddell, and depending on
// security requirements it may be a good idea to do so periodically.
//
//
// Here is an example exchange between two peers:
//
//   peer 1 -> waddell server : connect
//
//   waddell server -> peer 1 : send newly assigned peer id
//
//   peer 2 -> waddell server : connect
//
//   waddell server -> peer 2 : send newly assigned peer id
//
//   (out of band)            : peer 1 lets peer 2 know about its id
//
//   peer 2 -> waddell server : send message to peer 1
//
//   waddell server -> peer 1 : deliver message from peer 2 (includes peer 2's id)
//
//   peer 1 -> waddell server : send message to peer 2
//
//   etc ..
//
//
// Message structure on the wire (bits):
//
//   0-15    Frame Length    - waddell uses github.com/getlantern/framed to
//                             frame messages. framed uses the first 16 bits of
//                             the message to indicate the length of the frame
//                             (Little Endian).
//
//   16-79   Address Part 1  - 64-bit integer in Little Endian byte order for
//                             first half of peer id identifying recipient (on
//                             messages to waddell) or sender (on messages from
//                             waddell).
//
//   80-143  Address Part 2  - 64-bit integer in Little Endian byte order for
//                             second half of peer id
//
//   144-159 Topic ID        - 16-bit integer in Little Endian byte order
//                             identifying the topic of the communication
//
//   160+    Message Body    - whatever data the client sent
//
package waddell

import (
	"encoding/binary"
	"fmt"

	"github.com/getlantern/buuid"
	"github.com/getlantern/framed"
	"github.com/getlantern/golog"
)

const (
	PeerIdLength        = buuid.EncodedLength
	TopicIdLength       = 2
	WaddellHeaderLength = PeerIdLength + TopicIdLength
	WaddellOverhead     = framed.FrameHeaderLength + WaddellHeaderLength // bytes of overhead imposed by waddell
	MaxDataLength       = framed.MaxFrameLength - WaddellOverhead

	UnknownTopic = TopicId(0)
)

var (
	log = golog.LoggerFor("waddell")

	endianness = binary.LittleEndian

	keepAlive = []byte{'k'}
)

// MessageOut is a message to a waddell server
type MessageOut struct {
	To   PeerId
	Body [][]byte
}

// MessageIn is a message to a waddell server
type MessageIn struct {
	From  PeerId
	topic TopicId
	Body  []byte
}

// Message builds a new message to the given peer with the given body.
func Message(to PeerId, body ...[]byte) *MessageOut {
	return &MessageOut{to, body}
}

// PeerId is an identifier for a waddell peer
type PeerId buuid.ID

// PeerIdFromString constructs a PeerId from the string-encoded version of a
// uuid.UUID.
func PeerIdFromString(s string) (PeerId, error) {
	id, err := buuid.FromString(s)
	return PeerId(id), err
}

func (id PeerId) String() string {
	return buuid.ID(id).String()
}

func readPeerId(b []byte) (PeerId, error) {
	id, err := buuid.Read(b)
	return PeerId(id), err
}

func randomPeerId() PeerId {
	return PeerId(buuid.Random())
}

func (id PeerId) write(b []byte) error {
	return buuid.ID(id).Write(b)
}

func (id PeerId) toBytes() []byte {
	return buuid.ID(id).ToBytes()
}

// TopicId identifies a topic for messages.
type TopicId uint16

func readTopicId(b []byte) (TopicId, error) {
	if len(b) < TopicIdLength {
		return 0, fmt.Errorf("Insufficient data for decoding 16-bit TopicId")
	}
	id := endianness.Uint16(b)
	return TopicId(id), nil
}

func (id TopicId) toBytes() []byte {
	b := make([]byte, TopicIdLength)
	endianness.PutUint16(b, uint16(id))
	return b
}
