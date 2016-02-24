package dns

import (
	"bytes"
	"testing"
)

func TestDynamicUpdateParsing(t *testing.T) {
	prefix := "example.com. IN "
	for _, typ := range TypeToString {
		if typ == "OPT" || typ == "AXFR" || typ == "IXFR" || typ == "ANY" || typ == "TKEY" ||
			typ == "TSIG" || typ == "ISDN" || typ == "UNSPEC" || typ == "NULL" || typ == "ATMA" ||
			typ == "Reserved" || typ == "None" || typ == "NXT" || typ == "MAILB" || typ == "MAILA" {
			continue
		}
		r, err := NewRR(prefix + typ)
		if err != nil {
			t.Errorf("failure to parse: %s %s: %v", prefix, typ, err)
		} else {
			t.Logf("parsed: %s", r.String())
		}
	}
}

func TestDynamicUpdateUnpack(t *testing.T) {
	// From https://github.com/miekg/dns/issues/150#issuecomment-62296803
	// It should be an update message for the zone "example.",
	// deleting the A RRset "example." and then adding an A record at "example.".
	// class ANY, TYPE A
	buf := []byte{171, 68, 40, 0, 0, 1, 0, 0, 0, 2, 0, 0, 7, 101, 120, 97, 109, 112, 108, 101, 0, 0, 6, 0, 1, 192, 12, 0, 1, 0, 255, 0, 0, 0, 0, 0, 0, 192, 12, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 127, 0, 0, 1}
	msg := new(Msg)
	err := msg.Unpack(buf)
	if err != nil {
		t.Errorf("failed to unpack: %v\n%s", err, msg.String())
	}
}

func TestDynamicUpdateZeroRdataUnpack(t *testing.T) {
	m := new(Msg)
	rr := &RR_Header{Name: ".", Rrtype: 0, Class: 1, Ttl: ^uint32(0), Rdlength: 0}
	m.Answer = []RR{rr, rr, rr, rr, rr}
	m.Ns = m.Answer
	for n, s := range TypeToString {
		rr.Rrtype = n
		bytes, err := m.Pack()
		if err != nil {
			t.Errorf("failed to pack %s: %v", s, err)
			continue
		}
		if err := new(Msg).Unpack(bytes); err != nil {
			t.Errorf("failed to unpack %s: %v", s, err)
		}
	}
}

func TestRemoveRRset(t *testing.T) {
	// Should add a zero data RR in Class ANY with a TTL of 0
	// for each set mentioned in the RRs provided to it.
	rr, err := NewRR(". 100 IN A 127.0.0.1")
	if err != nil {
		t.Fatalf("error constructing RR: %v", err)
	}
	m := new(Msg)
	m.Ns = []RR{&RR_Header{Name: ".", Rrtype: TypeA, Class: ClassANY, Ttl: 0, Rdlength: 0}}
	expectstr := m.String()
	expect, err := m.Pack()
	if err != nil {
		t.Fatalf("error packing expected msg: %v", err)
	}

	m.Ns = nil
	m.RemoveRRset([]RR{rr})
	actual, err := m.Pack()
	if err != nil {
		t.Fatalf("error packing actual msg: %v", err)
	}
	if !bytes.Equal(actual, expect) {
		tmp := new(Msg)
		if err := tmp.Unpack(actual); err != nil {
			t.Fatalf("error unpacking actual msg: %v", err)
		}
		t.Errorf("expected msg:\n%s", expectstr)
		t.Errorf("actual msg:\n%v", tmp)
	}
}
