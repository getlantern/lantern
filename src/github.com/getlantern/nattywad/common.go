// package nattywad implements NAT traversal using go-natty and waddell.
package nattywad

import (
	"encoding/binary"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/waddell"
)

const (
	ServerReady = "ServerReady"
	Timeout     = 30 * time.Second

	NattywadTopic = waddell.TopicId(5001)
)

var (
	log = golog.LoggerFor("nattywad")

	maxWaddellMessageSize = 4096 + waddell.WaddellOverhead

	endianness = binary.LittleEndian
)

type traversalId uint32

type message []byte

func (msg message) setTraversalId(id traversalId) {
	endianness.PutUint32(msg[:4], uint32(id))
}

func (msg message) getTraversalId() traversalId {
	return traversalId(endianness.Uint32(msg[:4]))
}

func (msg message) getData() []byte {
	return msg[4:]
}

func (id traversalId) toBytes() []byte {
	b := make([]byte, 4)
	endianness.PutUint32(b, uint32(id))
	return b
}

// DefaultWaddellCert is the certificate for the production waddell server(s)
// used by, amongst other things, flashlight.
const DefaultWaddellCert = `-----BEGIN CERTIFICATE-----
MIIDkTCCAnmgAwIBAgIJAJKSxfu1psP7MA0GCSqGSIb3DQEBBQUAMF8xCzAJBgNV
BAYTAlVTMRMwEQYDVQQIDApTb21lLVN0YXRlMSkwJwYDVQQKDCBCcmF2ZSBOZXcg
U29mdHdhcmUgUHJvamVjdCwgSW5jLjEQMA4GA1UEAwwHd2FkZGVsbDAeFw0xNDEx
MDcyMDI5MDRaFw0xNTExMDcyMDI5MDRaMF8xCzAJBgNVBAYTAlVTMRMwEQYDVQQI
DApTb21lLVN0YXRlMSkwJwYDVQQKDCBCcmF2ZSBOZXcgU29mdHdhcmUgUHJvamVj
dCwgSW5jLjEQMA4GA1UEAwwHd2FkZGVsbDCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAOz22kAZXaVmFzo8+qaYbDyiZSc+D6j4+uQDlCFYsymdMSBaMRho
D3HNXAuvlmYGvZIc/jCM0LJ8m0MjS8DDa/EOWBDNcLV9ABxfqxPaAm2u8EU8vP8G
E3eGmoSrD0tB/OAF/utFvAEPNShwhMc2aY4qWPPrNqWa5U8f0JLnoZbnOWxMteU7
uSC+pRUbl3+tueWvFr+hXZMuGzb2Mes0UapJ//BKbaz0XboQ9Y7cRj8OiXjh3x4K
4Rz9qN8CrgOtwL9HNJ6krcgwaYIrf8O14Acc8VzcASLdtwEerHWgm2EZG+FZ24yP
ZwDLlcxJul29gjGnVpxDJaeB/1P18680fKECAwEAAaNQME4wHQYDVR0OBBYEFC9r
MKrgfqko3g/n8fgg3PUq7UCTMB8GA1UdIwQYMBaAFC9rMKrgfqko3g/n8fgg3PUq
7UCTMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAGlC2BrXcLZefm7G
IAZUjSj3nEPmoARH9Y2lxR78/FtAXu3WwXFeDY5wq1HRDWMUB/usBNk+19SXQjxF
ykZGqc5on7QSqbu489Kh37Jenfi6MGXPFh1brFaNuCndW3x/x2wer+k/y7HAXTN0
OGRaZaCqwkFoI0GCnmJUJdA1ahBYMkqFcWrvuw4aDzvfWYCfFUmADQdkb+xJGGiF
plISFgS/kDrK3OfIBu8S+XuhAIlzXKnHb+887pcvpm4f3zVv7rB8amv10x2E5fjS
RnCIHFZ4k1Au8N60Da3Z28hizafJeV4uHbzjYU+n8XpVqFqJI83CdsbiZ+nXO87G
pUWu27U=
-----END CERTIFICATE-----`
