// Copyright 2012 Google, Inc. All rights reserved.
// Copyright 2009-2011 Andreas Krennmair. All rights reserved.
//
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file in the root of the source
// tree.

package layers

import (
	"encoding/binary"
	"fmt"
	"github.com/google/gopacket"
	"strconv"
)

type ICMPv6TypeCode uint16

const (
	ICMPv6TypeDestinationUnreachable = 1
	ICMPv6TypePacketTooBig           = 2
	ICMPv6TypeTimeExceeded           = 3
	ICMPv6TypeParameterProblem       = 4
	ICMPv6TypeEchoRequest            = 128
	ICMPv6TypeEchoReply              = 129
	// The following are from RFC 4861
	ICMPv6TypeRouterSolicitation    = 133
	ICMPv6TypeRouterAdvertisement   = 134
	ICMPv6TypeNeighborSolicitation  = 135
	ICMPv6TypeNeighborAdvertisement = 136
	ICMPv6TypeRedirect              = 137
)

func (a ICMPv6TypeCode) String() string {
	typ := uint8(a >> 8)
	code := uint8(a)
	var typeStr, codeStr string
	switch typ {
	case ICMPv6TypeDestinationUnreachable:
		typeStr = "DestinationUnreachable"
		switch code {
		case 0:
			codeStr = "NoRouteToDst"
		case 1:
			codeStr = "AdminProhibited"
		case 3:
			codeStr = "Address"
		case 4:
			codeStr = "Port"
		}
	case ICMPv6TypePacketTooBig:
		typeStr = "PacketTooBig"
	case ICMPv6TypeTimeExceeded:
		typeStr = "TimeExceeded"
		switch code {
		case 0:
			codeStr = "HopLimitExceeded"
		case 1:
			codeStr = "FragmentReassemblyTimeExceeded"
		}
	case ICMPv6TypeParameterProblem:
		typeStr = "ParameterProblem"
		switch code {
		case 0:
			codeStr = "ErroneousHeader"
		case 1:
			codeStr = "UnrecognizedNextHeader"
		case 2:
			codeStr = "UnrecognizedIPv6Option"
		}
	case ICMPv6TypeEchoRequest:
		typeStr = "EchoRequest"
	case ICMPv6TypeEchoReply:
		typeStr = "EchoReply"
	case ICMPv6TypeRouterSolicitation:
		typeStr = "RouterSolicitation"
	case ICMPv6TypeRouterAdvertisement:
		typeStr = "RouterAdvertisement"
	case ICMPv6TypeNeighborSolicitation:
		typeStr = "NeighborSolicitation"
	case ICMPv6TypeNeighborAdvertisement:
		typeStr = "NeighborAdvertisement"
	case ICMPv6TypeRedirect:
		typeStr = "Redirect"
	default:
		typeStr = strconv.Itoa(int(typ))
	}
	if codeStr == "" {
		codeStr = strconv.Itoa(int(code))
	}
	return fmt.Sprintf("%s(%s)", typeStr, codeStr)
}

// ICMPv6 is the layer for IPv6 ICMP packet data
type ICMPv6 struct {
	BaseLayer
	TypeCode  ICMPv6TypeCode
	Checksum  uint16
	TypeBytes []byte
	tcpipchecksum
}

// LayerType returns LayerTypeICMPv6.
func (i *ICMPv6) LayerType() gopacket.LayerType { return LayerTypeICMPv6 }

// DecodeFromBytes decodes the given bytes into this layer.
func (i *ICMPv6) DecodeFromBytes(data []byte, df gopacket.DecodeFeedback) error {
	i.TypeCode = ICMPv6TypeCode(binary.BigEndian.Uint16(data[:2]))
	i.Checksum = binary.BigEndian.Uint16(data[2:4])
	i.TypeBytes = data[4:8]
	i.BaseLayer = BaseLayer{data[:8], data[8:]}
	return nil
}

// SerializeTo writes the serialized form of this layer into the
// SerializationBuffer, implementing gopacket.SerializableLayer.
// See the docs for gopacket.SerializableLayer for more info.
func (i *ICMPv6) SerializeTo(b gopacket.SerializeBuffer, opts gopacket.SerializeOptions) error {
	if i.TypeBytes == nil {
		i.TypeBytes = lotsOfZeros[:4]
	} else if len(i.TypeBytes) != 4 {
		return fmt.Errorf("invalid type bytes for ICMPv6 packet: %v", i.TypeBytes)
	}
	bytes, err := b.PrependBytes(8)
	if err != nil {
		return err
	}
	binary.BigEndian.PutUint16(bytes, uint16(i.TypeCode))
	copy(bytes[4:8], i.TypeBytes)
	if opts.ComputeChecksums {
		bytes[2] = 0
		bytes[3] = 0
		csum, err := i.computeChecksum(b.Bytes(), IPProtocolICMPv6)
		if err != nil {
			return err
		}
		i.Checksum = csum
	}
	binary.BigEndian.PutUint16(bytes[2:], i.Checksum)
	return nil
}

// CanDecode returns the set of layer types that this DecodingLayer can decode.
func (i *ICMPv6) CanDecode() gopacket.LayerClass {
	return LayerTypeICMPv6
}

// NextLayerType returns the layer type contained by this DecodingLayer.
func (i *ICMPv6) NextLayerType() gopacket.LayerType {
	return gopacket.LayerTypePayload
}

func decodeICMPv6(data []byte, p gopacket.PacketBuilder) error {
	i := &ICMPv6{}
	return decodingLayerDecoder(i, data, p)
}
