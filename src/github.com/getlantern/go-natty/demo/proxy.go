package main

import (
	"encoding/binary"
	"flag"
	"log"
	"net"
	"time"

	"github.com/getlantern/waddell"
)

const (
	// TODO: figure out maximum required size for messages
	MAX_MESSAGE_SIZE = 4096

	READY = "READY"

	TIMEOUT = 15 * time.Second

	DemoTopic = waddell.TopicId(10000)
)

var (
	endianness = binary.LittleEndian

	help        = flag.Bool("help", false, "Get usage help")
	mode        = flag.String("mode", "client", "client or server. Client initiates the NAT traversal. Defaults to client.")
	waddellAddr = flag.String("waddell", "128.199.130.61:443", "Address of waddell signaling server, defaults to 128.199.130.61:443")
	waddellCert = flag.String("waddellcert", DefaultWaddellCert, "Certificate for waddell server")

	wc  *waddell.Client
	id  waddell.PeerId
	out chan<- *waddell.MessageOut
	in  <-chan *waddell.MessageIn
)

// message represents a message exchanged during a NAT traversal
type message []byte

func (msg message) setTraversalId(id uint32) {
	endianness.PutUint32(msg[:4], id)
}

func (msg message) getTraversalId() uint32 {
	return endianness.Uint32(msg[:4])
}

func (msg message) getData() []byte {
	return msg[4:]
}

func idToBytes(id uint32) []byte {
	b := make([]byte, 4)
	endianness.PutUint32(b[:4], id)
	return b
}

func main() {
	flag.Parse()
	if *help {
		flag.Usage()
		return
	}

	connectToWaddell()

	if "server" == *mode {
		runServer()
	} else {
		runClient()
	}
}

func connectToWaddell() {
	var err error
	wc, err = waddell.NewClient(&waddell.ClientConfig{
		Dial: func() (net.Conn, error) {
			return net.Dial("tcp", *waddellAddr)
		},
		ServerCert: *waddellCert,
	})
	if err != nil {
		log.Fatalf("Unable to connect to waddell: %s", err)
	}
	log.Printf("Connected")
	out = wc.Out(DemoTopic)
	in = wc.In(DemoTopic)
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
