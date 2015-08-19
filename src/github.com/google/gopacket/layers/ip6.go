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
	"net"
)

// IPv6 is the layer for the IPv6 header.
type IPv6 struct {
	// http://www.networksorcery.com/enp/protocol/ipv6.htm
	BaseLayer
	Version      uint8
	TrafficClass uint8
	FlowLabel    uint32
	Length       uint16
	NextHeader   IPProtocol
	HopLimit     uint8
	SrcIP        net.IP
	DstIP        net.IP
	HopByHop     *IPv6HopByHop
	// hbh will be pointed to by HopByHop if that layer exists.
	hbh IPv6HopByHop
}

// LayerType returns LayerTypeIPv6
func (i *IPv6) LayerType() gopacket.LayerType { return LayerTypeIPv6 }
func (i *IPv6) NetworkFlow() gopacket.Flow {
	return gopacket.NewFlow(EndpointIPv6, i.SrcIP, i.DstIP)
}

const (
	IPv6HopByHopOptionJumbogram = 0xC2 // RFC 2675
)

// SerializeTo writes the serialized form of this layer into the
// SerializationBuffer, implementing gopacket.SerializableLayer.
// See the docs for gopacket.SerializableLayer for more info.
func (ip6 *IPv6) SerializeTo(b gopacket.SerializeBuffer, opts gopacket.SerializeOptions) error {
	payload := b.Bytes()
	if ip6.HopByHop != nil {
		return fmt.Errorf("unable to serialize hopbyhop for now")
	}
	bytes, err := b.PrependBytes(40)
	if err != nil {
		return err
	}
	bytes[0] = (ip6.Version << 4) | (ip6.TrafficClass >> 4)
	bytes[1] = (ip6.TrafficClass << 4) | uint8(ip6.FlowLabel>>16)
	binary.BigEndian.PutUint16(bytes[2:], uint16(ip6.FlowLabel))
	if opts.FixLengths {
		ip6.Length = uint16(len(payload))
	}
	binary.BigEndian.PutUint16(bytes[4:], ip6.Length)
	bytes[6] = byte(ip6.NextHeader)
	bytes[7] = byte(ip6.HopLimit)
	if err := ip6.AddressTo16(); err != nil {
		return err
	}
	copy(bytes[8:], ip6.SrcIP)
	copy(bytes[24:], ip6.DstIP)
	return nil
}

func (ip6 *IPv6) DecodeFromBytes(data []byte, df gopacket.DecodeFeedback) error {
	ip6.Version = uint8(data[0]) >> 4
	ip6.TrafficClass = uint8((binary.BigEndian.Uint16(data[0:2]) >> 4) & 0x00FF)
	ip6.FlowLabel = binary.BigEndian.Uint32(data[0:4]) & 0x000FFFFF
	ip6.Length = binary.BigEndian.Uint16(data[4:6])
	ip6.NextHeader = IPProtocol(data[6])
	ip6.HopLimit = data[7]
	ip6.SrcIP = data[8:24]
	ip6.DstIP = data[24:40]
	ip6.HopByHop = nil
	// We initially set the payload to all bytes after 40.  ip6.Length or the
	// HopByHop jumbogram option can both change this eventually, though.
	ip6.BaseLayer = BaseLayer{data[:40], data[40:]}

	// We treat a HopByHop IPv6 option as part of the IPv6 packet, since its
	// options are crucial for understanding what's actually happening per packet.
	if ip6.NextHeader == IPProtocolIPv6HopByHop {
		ip6.hbh.DecodeFromBytes(ip6.Payload, df)
		hbhLen := len(ip6.hbh.Contents)
		// Reset IPv6 contents to include the HopByHop header.
		ip6.BaseLayer = BaseLayer{data[:40+hbhLen], data[40+hbhLen:]}
		ip6.HopByHop = &ip6.hbh
		if ip6.Length == 0 {
			for _, o := range ip6.hbh.Options {
				if o.OptionType == IPv6HopByHopOptionJumbogram {
					if len(o.OptionData) != 4 {
						return fmt.Errorf("Invalid jumbo packet option length")
					}
					payloadLength := binary.BigEndian.Uint32(o.OptionData)
					pEnd := int(payloadLength)
					if pEnd > len(ip6.Payload) {
						df.SetTruncated()
					} else {
						ip6.Payload = ip6.Payload[:pEnd]
						ip6.hbh.Payload = ip6.Payload
					}
					return nil
				}
			}
			return fmt.Errorf("IPv6 length 0, but HopByHop header does not have jumbogram option")
		}
	}
	if ip6.Length == 0 {
		return fmt.Errorf("IPv6 length 0, but next header is %v, not HopByHop", ip6.NextHeader)
	} else {
		pEnd := int(ip6.Length)
		if pEnd > len(ip6.Payload) {
			df.SetTruncated()
			pEnd = len(ip6.Payload)
		}
		ip6.Payload = ip6.Payload[:pEnd]
	}
	return nil
}

func (i *IPv6) CanDecode() gopacket.LayerClass {
	return LayerTypeIPv6
}
func (i *IPv6) NextLayerType() gopacket.LayerType {
	if i.HopByHop != nil {
		return i.HopByHop.NextHeader.LayerType()
	}
	return i.NextHeader.LayerType()
}

func decodeIPv6(data []byte, p gopacket.PacketBuilder) error {
	ip6 := &IPv6{}
	err := ip6.DecodeFromBytes(data, p)
	p.AddLayer(ip6)
	p.SetNetworkLayer(ip6)
	if ip6.HopByHop != nil {
		// TODO(gconnell):  Since HopByHop is now an integral part of the IPv6
		// layer, should it actually be added as its own layer?  I'm leaning towards
		// no.
		p.AddLayer(ip6.HopByHop)
	}
	if err != nil {
		return err
	}
	if ip6.HopByHop != nil {
		return p.NextDecoder(ip6.HopByHop.NextHeader)
	}
	return p.NextDecoder(ip6.NextHeader)
}

func (i *IPv6HopByHop) DecodeFromBytes(data []byte, df gopacket.DecodeFeedback) error {
	i.ipv6ExtensionBase = decodeIPv6ExtensionBase(data)
	i.Options = i.opts[:0]
	var opt *IPv6HopByHopOption
	for d := i.Contents[2:]; len(d) > 0; d = d[opt.ActualLength:] {
		i.Options = append(i.Options, IPv6HopByHopOption(decodeIPv6HeaderTLVOption(d)))
		opt = &i.Options[len(i.Options)-1]
	}
	return nil
}

func decodeIPv6HopByHop(data []byte, p gopacket.PacketBuilder) error {
	i := &IPv6HopByHop{}
	err := i.DecodeFromBytes(data, p)
	p.AddLayer(i)
	if err != nil {
		return err
	}
	return p.NextDecoder(i.NextHeader)
}

type ipv6HeaderTLVOption struct {
	OptionType, OptionLength uint8
	ActualLength             int
	OptionData               []byte
}

func decodeIPv6HeaderTLVOption(data []byte) (h ipv6HeaderTLVOption) {
	if data[0] == 0 {
		h.ActualLength = 1
		return
	}
	h.OptionType = data[0]
	h.OptionLength = data[1]
	h.ActualLength = int(h.OptionLength) + 2
	h.OptionData = data[2:h.ActualLength]
	return
}

func (h *ipv6HeaderTLVOption) serializeTo(b gopacket.SerializeBuffer, fixLengths bool) (int, error) {
	if fixLengths {
		h.OptionLength = uint8(len(h.OptionData))
	}
	length := int(h.OptionLength) + 2
	data, err := b.PrependBytes(length)
	if err != nil {
		return 0, err
	}
	data[0] = h.OptionType
	data[1] = h.OptionLength
	copy(data[2:], h.OptionData)
	return length, nil
}

// IPv6HopByHopOption is a TLV option present in an IPv6 hop-by-hop extension.
type IPv6HopByHopOption ipv6HeaderTLVOption

type ipv6ExtensionBase struct {
	BaseLayer
	NextHeader   IPProtocol
	HeaderLength uint8
	ActualLength int
}

func decodeIPv6ExtensionBase(data []byte) (i ipv6ExtensionBase) {
	i.NextHeader = IPProtocol(data[0])
	i.HeaderLength = data[1]
	i.ActualLength = int(i.HeaderLength)*8 + 8
	i.Contents = data[:i.ActualLength]
	i.Payload = data[i.ActualLength:]
	return
}

// IPv6ExtensionSkipper is a DecodingLayer which decodes and ignores v6
// extensions.  You can use it with a DecodingLayerParser to handle IPv6 stacks
// which may or may not have extensions.
type IPv6ExtensionSkipper struct {
	NextHeader IPProtocol
	BaseLayer
}

func (i *IPv6ExtensionSkipper) DecodeFromBytes(data []byte, df gopacket.DecodeFeedback) error {
	extension := decodeIPv6ExtensionBase(data)
	i.BaseLayer = BaseLayer{data[:extension.ActualLength], data[extension.ActualLength:]}
	i.NextHeader = extension.NextHeader
	return nil
}
func (i *IPv6ExtensionSkipper) CanDecode() gopacket.LayerClass {
	return LayerClassIPv6Extension
}
func (i *IPv6ExtensionSkipper) NextLayerType() gopacket.LayerType {
	return i.NextHeader.LayerType()
}

// IPv6HopByHop is the IPv6 hop-by-hop extension.
type IPv6HopByHop struct {
	ipv6ExtensionBase
	Options []IPv6HopByHopOption
	opts    [2]IPv6HopByHopOption
}

// LayerType returns LayerTypeIPv6HopByHop.
func (i *IPv6HopByHop) LayerType() gopacket.LayerType { return LayerTypeIPv6HopByHop }

// IPv6Routing is the IPv6 routing extension.
type IPv6Routing struct {
	ipv6ExtensionBase
	RoutingType  uint8
	SegmentsLeft uint8
	// This segment is supposed to be zero according to RFC2460, the second set of
	// 4 bytes in the extension.
	Reserved []byte
	// SourceRoutingIPs is the set of IPv6 addresses requested for source routing,
	// set only if RoutingType == 0.
	SourceRoutingIPs []net.IP
}

// LayerType returns LayerTypeIPv6Routing.
func (i *IPv6Routing) LayerType() gopacket.LayerType { return LayerTypeIPv6Routing }

func decodeIPv6Routing(data []byte, p gopacket.PacketBuilder) error {
	i := &IPv6Routing{
		ipv6ExtensionBase: decodeIPv6ExtensionBase(data),
		RoutingType:       data[2],
		SegmentsLeft:      data[3],
		Reserved:          data[4:8],
	}
	switch i.RoutingType {
	case 0: // Source routing
		if (i.ActualLength-8)%16 != 0 {
			return fmt.Errorf("Invalid IPv6 source routing, length of type 0 packet %d", i.ActualLength)
		}
		for d := i.Contents[8:]; len(d) >= 16; d = d[16:] {
			i.SourceRoutingIPs = append(i.SourceRoutingIPs, net.IP(d[:16]))
		}
	default:
		return fmt.Errorf("Unknown IPv6 routing header type %d", i.RoutingType)
	}
	p.AddLayer(i)
	return p.NextDecoder(i.NextHeader)
}

// IPv6Fragment is the IPv6 fragment header, used for packet
// fragmentation/defragmentation.
type IPv6Fragment struct {
	BaseLayer
	NextHeader IPProtocol
	// Reserved1 is bits [8-16), from least to most significant, 0-indexed
	Reserved1      uint8
	FragmentOffset uint16
	// Reserved2 is bits [29-31), from least to most significant, 0-indexed
	Reserved2      uint8
	MoreFragments  bool
	Identification uint32
}

// LayerType returns LayerTypeIPv6Fragment.
func (i *IPv6Fragment) LayerType() gopacket.LayerType { return LayerTypeIPv6Fragment }

func decodeIPv6Fragment(data []byte, p gopacket.PacketBuilder) error {
	i := &IPv6Fragment{
		BaseLayer:      BaseLayer{data[:8], data[8:]},
		NextHeader:     IPProtocol(data[0]),
		Reserved1:      data[1],
		FragmentOffset: binary.BigEndian.Uint16(data[2:4]) >> 3,
		Reserved2:      data[3] & 0x6 >> 1,
		MoreFragments:  data[3]&0x1 != 0,
		Identification: binary.BigEndian.Uint32(data[4:8]),
	}
	p.AddLayer(i)
	return p.NextDecoder(gopacket.DecodeFragment)
}

// IPv6DestinationOption is a TLV option present in an IPv6 destination options extension.
type IPv6DestinationOption ipv6HeaderTLVOption

func (o *IPv6DestinationOption) serializeTo(b gopacket.SerializeBuffer, fixLengths bool) (int, error) {
	return (*ipv6HeaderTLVOption)(o).serializeTo(b, fixLengths)
}

// IPv6Destination is the IPv6 destination options header.
type IPv6Destination struct {
	ipv6ExtensionBase
	Options []IPv6DestinationOption
}

// LayerType returns LayerTypeIPv6Destination.
func (i *IPv6Destination) LayerType() gopacket.LayerType { return LayerTypeIPv6Destination }

func decodeIPv6Destination(data []byte, p gopacket.PacketBuilder) error {
	i := &IPv6Destination{
		ipv6ExtensionBase: decodeIPv6ExtensionBase(data),
		// We guess we'll 1-2 options, one regular option at least, then maybe one
		// padding option.
		Options: make([]IPv6DestinationOption, 0, 2),
	}
	var opt *IPv6DestinationOption
	for d := i.Contents[2:]; len(d) > 0; d = d[opt.ActualLength:] {
		i.Options = append(i.Options, IPv6DestinationOption(decodeIPv6HeaderTLVOption(d)))
		opt = &i.Options[len(i.Options)-1]
	}
	p.AddLayer(i)
	return p.NextDecoder(i.NextHeader)
}

// SerializeTo writes the serialized form of this layer into the
// SerializationBuffer, implementing gopacket.SerializableLayer.
// See the docs for gopacket.SerializableLayer for more info.
func (i *IPv6Destination) SerializeTo(b gopacket.SerializeBuffer, opts gopacket.SerializeOptions) error {
	optionLength := 0
	for _, opt := range i.Options {
		l, err := opt.serializeTo(b, opts.FixLengths)
		if err != nil {
			return err
		}
		optionLength += l
	}
	bytes, err := b.PrependBytes(2)
	if err != nil {
		return err
	}
	bytes[0] = uint8(i.NextHeader)
	if opts.FixLengths {
		if optionLength <= 0 {
			return fmt.Errorf("cannot serialize empty IPv6Destination")
		}
		length := optionLength + 2
		if length % 8 != 0 {
			return fmt.Errorf("IPv6Destination actual length must be multiple of 8 (check TLV alignment)")
		}
		i.HeaderLength = uint8((length / 8) - 1)
	}
	bytes[1] = i.HeaderLength
	return nil
}

func checkIPv6Address(addr net.IP) error {
	if len(addr) == net.IPv6len {
		return nil
	}
	if len(addr) == net.IPv4len {
		return fmt.Errorf("address is IPv4")
	}
	return fmt.Errorf("wrong length of %d bytes instead of %d", len(addr), net.IPv6len)
}

func (ip *IPv6) AddressTo16() error {
	if err := checkIPv6Address(ip.SrcIP); err != nil {
		return fmt.Errorf("Invalid source IPv6 address (%s)", err)
	}
	if err := checkIPv6Address(ip.DstIP); err != nil {
		return fmt.Errorf("Invalid destination IPv6 address (%s)", err)
	}
	return nil
}
