// Package buuid provides a type 4 uuid that can be encoded into a 16 byte
// binary representation as two 64 bit integers in little endian byte order.
package buuid

import (
	"encoding/binary"
	"fmt"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/golog"
)

const (
	EncodedLength = 16
)

var (
	endianness = binary.LittleEndian
	zero       = ID{}

	log = golog.LoggerFor("buuid")
)

// ID is a type 4 UUID.
type ID struct {
	part1 uint64
	part2 uint64
}

// Random creates a random ID (uses uuid.NewRandom() which uses crypto.Random()
// under the covers)
func Random() ID {
	id, err := Read(uuid.NewRandom())
	if err != nil {
		panic(fmt.Sprintf("Unable to generate random peer id: %s", err))
	}
	return id
}

// Read reads the ID from a 16-byte or larger buffer
func Read(b []byte) (ID, error) {
	if len(b) < EncodedLength {
		return zero, fmt.Errorf("Insufficient data to read id, data may be truncated")
	}
	return ID{
		endianness.Uint64(b[0:8]),
		endianness.Uint64(b[8:]),
	}, nil
}

// Write writes the ID to a 16-byte or larger buffer
func (id ID) Write(b []byte) error {
	if len(b) < EncodedLength {
		return fmt.Errorf("Insufficient room to write id")
	}
	endianness.PutUint64(b, id.part1)
	endianness.PutUint64(b[8:], id.part2)
	return nil
}

// ToBytes returns a 16-byte representation of this ID
func (id ID) ToBytes() []byte {
	b := make([]byte, EncodedLength)
	if err := id.Write(b); err != nil {
		log.Errorf("Unable to write as 16-bytes representation: %v", err)
	}
	return b
}

// FromString constructs an ID from the string-encoded version of a uuid.UUID.
func FromString(s string) (ID, error) {
	return Read(uuid.Parse(s))
}

// String() returns the string-encoded version like in uuid.UUID.
func (id ID) String() string {
	b := uuid.UUID(make([]byte, EncodedLength))
	if err := id.Write([]byte(b)); err != nil {
		log.Errorf("Unable to write as string: %v", err)
	}
	return b.String()
}
