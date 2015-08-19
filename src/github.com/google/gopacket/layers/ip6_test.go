// Copyright 2014, Google, Inc. All rights reserved.
//
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file in the root of the source
// tree.

package layers

import (
	"github.com/google/gopacket"
	"net"
	"reflect"
	"testing"
)

// testPacketIPv6Destination0 is the packet:
//   12:40:14.429409595 IP6 2001:db8::1 > 2001:db8::2: DSTOPT no next header
//   	0x0000:  6000 0000 0008 3c40 2001 0db8 0000 0000  `.....<@........
//   	0x0010:  0000 0000 0000 0001 2001 0db8 0000 0000  ................
//   	0x0020:  0000 0000 0000 0002 3b00 0104 0000 0000  ........;.......
var testPacketIPv6Destination0 = []byte{
	0x60, 0x00, 0x00, 0x00, 0x00, 0x08, 0x3c, 0x40, 0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x3b, 0x00, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00,
}

func TestPacketIPv6Destination0Serialize(t *testing.T) {
	var serialize []gopacket.SerializableLayer = make([]gopacket.SerializableLayer, 0, 2)
	var err error

	ip6 := &IPv6{}
	ip6.Version = 6
	ip6.NextHeader = IPProtocolIPv6Destination
	ip6.HopLimit = 64
	ip6.SrcIP = net.ParseIP("2001:db8::1")
	ip6.DstIP = net.ParseIP("2001:db8::2")
	serialize = append(serialize, ip6)

	tlv := &IPv6DestinationOption{}
	tlv.OptionType = 0x01 //PadN
	tlv.OptionData = []byte{0x00, 0x00, 0x00, 0x00}
	dst := &IPv6Destination{}
	dst.Options = append(dst.Options, *tlv)
	dst.NextHeader = IPProtocolNoNextHeader
	serialize = append(serialize, dst)

	buf := gopacket.NewSerializeBuffer()
	opts := gopacket.SerializeOptions{FixLengths: true, ComputeChecksums: true}
	err = gopacket.SerializeLayers(buf, opts, serialize...)
	if err != nil {
		t.Fatal(err)
	}

	got := buf.Bytes()
	want := testPacketIPv6Destination0
	if !reflect.DeepEqual(got, want) {
		t.Errorf("IPv6Destination serialize failed:\ngot:\n%#v\n\nwant:\n%#v\n\n", got, want)
	}
}

func TestPacketIPv6Destination0Decode(t *testing.T) {
	p := gopacket.NewPacket(testPacketIPv6Destination0, LinkTypeRaw, gopacket.Default)
	if p.ErrorLayer() != nil {
		t.Error("Failed to decode packet:", p.ErrorLayer().Error())
	}
	checkLayers(p, []gopacket.LayerType{LayerTypeIPv6, LayerTypeIPv6Destination}, t)
	if got, ok := p.Layer(LayerTypeIPv6).(*IPv6); ok {
		want := &IPv6{
			BaseLayer: BaseLayer{
				Contents: []byte{
					0x60, 0x00, 0x00, 0x00, 0x00, 0x08, 0x3c, 0x40, 0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
					0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
					0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
				},
				Payload: []byte{0x3b, 0x00, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00},
			},
			Version:      6,
			TrafficClass: 0,
			FlowLabel:    0,
			Length:       8,
			NextHeader:   IPProtocolIPv6Destination,
			HopLimit:     64,
			SrcIP:        net.IP{0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01},
			DstIP: net.IP{0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02},
		}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("IPv6 packet processing failed:\ngot  :\n%#v\n\nwant :\n%#v\n\n", got, want)
		}
	} else {
		t.Error("No IPv6 layer type found in packet")
	}
	if got, ok := p.Layer(LayerTypeIPv6Destination).(*IPv6Destination); ok {
		want := &IPv6Destination{}
		want.BaseLayer = BaseLayer{
			Contents: []byte{0x3b, 0x00, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00},
			Payload:  []byte{},
		}
		want.NextHeader = IPProtocolNoNextHeader
		want.HeaderLength = uint8(0)
		want.ActualLength = 8
		opt := IPv6DestinationOption{
			OptionType:   uint8(0x01),
			OptionLength: uint8(0x04),
			ActualLength: 6,
			OptionData:   []byte{0x00, 0x00, 0x00, 0x00},
		}
		want.Options = append(want.Options, opt)
		if !reflect.DeepEqual(got, want) {
			t.Errorf("IPV6Destination packet processing failed:\ngot  :\n%#v\n\nwant :\n%#v\n\n", got, want)
		}
	} else {
		t.Error("No IPv6Destination layer type found in packet")
	}
}
