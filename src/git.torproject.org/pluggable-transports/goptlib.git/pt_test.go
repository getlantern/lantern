package pt

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"os"
	"path"
	"sort"
	"testing"
)

func TestKeywordIsSafe(t *testing.T) {
	tests := [...]struct {
		keyword  string
		expected bool
	}{
		{"", true},
		{"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_", true},
		{"CMETHOD", true},
		{"CMETHOD:", false},
		{"a b c", false},
		{"CMETHOD\x7f", false},
		{"CMETHOD\x80", false},
		{"CMETHOD\x81", false},
		{"CMETHOD\xff", false},
		{"CMÉTHOD", false},
	}

	for _, input := range tests {
		isSafe := keywordIsSafe(input.keyword)
		if isSafe != input.expected {
			t.Errorf("keywordIsSafe(%q) → %v (expected %v)",
				input.keyword, isSafe, input.expected)
		}
	}
}

func TestArgIsSafe(t *testing.T) {
	tests := [...]struct {
		arg      string
		expected bool
	}{
		{"", true},
		{"abc", true},
		{"127.0.0.1:8000", true},
		{"étude", false},
		{"a\nb", false},
		{"a\\b", true},
		{"ab\\", true},
		{"ab\\\n", false},
		{"ab\n\\", false},
		{"abc\x7f", true},
		{"abc\x80", false},
		{"abc\x81", false},
		{"abc\xff", false},
		{"abc\xff", false},
		{"var=GVsbG8\\=", true},
	}

	for _, input := range tests {
		isSafe := argIsSafe(input.arg)
		if isSafe != input.expected {
			t.Errorf("argIsSafe(%q) → %v (expected %v)",
				input.arg, isSafe, input.expected)
		}
	}
}

func TestGetManagedTransportVer(t *testing.T) {
	badTests := [...]string{
		"",
		"2",
	}
	goodTests := [...]struct {
		input, expected string
	}{
		{"1", "1"},
		{"1,1", "1"},
		{"1,2", "1"},
		{"2,1", "1"},
	}

	Stdout = ioutil.Discard

	os.Clearenv()
	_, err := getManagedTransportVer()
	if err == nil {
		t.Errorf("empty environment unexpectedly succeeded")
	}

	for _, input := range badTests {
		os.Setenv("TOR_PT_MANAGED_TRANSPORT_VER", input)
		_, err := getManagedTransportVer()
		if err == nil {
			t.Errorf("TOR_PT_MANAGED_TRANSPORT_VER=%q unexpectedly succeeded", input)
		}
	}

	for _, test := range goodTests {
		os.Setenv("TOR_PT_MANAGED_TRANSPORT_VER", test.input)
		output, err := getManagedTransportVer()
		if err != nil {
			t.Errorf("TOR_PT_MANAGED_TRANSPORT_VER=%q unexpectedly returned an error: %s", test.input, err)
		}
		if output != test.expected {
			t.Errorf("TOR_PT_MANAGED_TRANSPORT_VER=%q → %q (expected %q)", test.input, output, test.expected)
		}
	}
}

// return true iff the two slices contain the same elements, possibly in a
// different order.
func stringSetsEqual(a, b []string) bool {
	ac := make([]string, len(a))
	bc := make([]string, len(b))
	copy(ac, a)
	copy(bc, b)
	sort.Strings(ac)
	sort.Strings(bc)
	if len(ac) != len(bc) {
		return false
	}
	for i := 0; i < len(ac); i++ {
		if ac[i] != bc[i] {
			return false
		}
	}
	return true
}

func tcpAddrsEqual(a, b *net.TCPAddr) bool {
	return a.IP.Equal(b.IP) && a.Port == b.Port
}

func TestGetClientTransports(t *testing.T) {
	tests := [...]struct {
		ptClientTransports string
		expected           []string
	}{
		{
			"alpha",
			[]string{"alpha"},
		},
		{
			"alpha,beta",
			[]string{"alpha", "beta"},
		},
		{
			"alpha,beta,gamma",
			[]string{"alpha", "beta", "gamma"},
		},
		// In the past, "*" meant to return all known transport names.
		// But now it has no special meaning.
		// https://trac.torproject.org/projects/tor/ticket/15612
		{
			"*",
			[]string{"*"},
		},
		{
			"alpha,*,gamma",
			[]string{"alpha", "*", "gamma"},
		},
		// No escaping is defined for TOR_PT_CLIENT_TRANSPORTS.
		{
			`alpha\,beta`,
			[]string{`alpha\`, `beta`},
		},
	}

	Stdout = ioutil.Discard

	os.Clearenv()
	_, err := getClientTransports()
	if err == nil {
		t.Errorf("empty environment unexpectedly succeeded")
	}

	for _, test := range tests {
		os.Setenv("TOR_PT_CLIENT_TRANSPORTS", test.ptClientTransports)
		output, err := getClientTransports()
		if err != nil {
			t.Errorf("TOR_PT_CLIENT_TRANSPORTS=%q unexpectedly returned an error: %s",
				test.ptClientTransports, err)
		}
		if !stringSetsEqual(output, test.expected) {
			t.Errorf("TOR_PT_CLIENT_TRANSPORTS=%q → %q (expected %q)",
				test.ptClientTransports, output, test.expected)
		}
	}
}

func TestResolveAddr(t *testing.T) {
	badTests := [...]string{
		"",
		"1.2.3.4",
		"1.2.3.4:",
		"9999",
		":9999",
		"[1:2::3:4]",
		"[1:2::3:4]:",
		"[1::2::3:4]",
		"1:2::3:4::9999",
		"1:2:3:4::9999",
		"localhost:9999",
		"[localhost]:9999",
		"1.2.3.4:http",
		"1.2.3.4:0x50",
		"1.2.3.4:-65456",
		"1.2.3.4:65536",
		"1.2.3.4:80\x00",
		"1.2.3.4:80 ",
		" 1.2.3.4:80",
		"1.2.3.4 : 80",
	}
	goodTests := [...]struct {
		input    string
		expected net.TCPAddr
	}{
		{"1.2.3.4:9999", net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 9999}},
		{"[1:2::3:4]:9999", net.TCPAddr{IP: net.ParseIP("1:2::3:4"), Port: 9999}},
		{"1:2::3:4:9999", net.TCPAddr{IP: net.ParseIP("1:2::3:4"), Port: 9999}},
	}

	for _, input := range badTests {
		output, err := resolveAddr(input)
		if err == nil {
			t.Errorf("%q unexpectedly succeeded: %q", input, output)
		}
	}

	for _, test := range goodTests {
		output, err := resolveAddr(test.input)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", test.input, err)
		}
		if !tcpAddrsEqual(output, &test.expected) {
			t.Errorf("%q → %q (expected %q)", test.input, output, test.expected)
		}
	}
}

func bindaddrSliceContains(s []Bindaddr, v Bindaddr) bool {
	for _, sv := range s {
		if sv.MethodName == v.MethodName && tcpAddrsEqual(sv.Addr, v.Addr) {
			return true
		}
	}
	return false
}

func bindaddrSetsEqual(a, b []Bindaddr) bool {
	for _, v := range a {
		if !bindaddrSliceContains(b, v) {
			return false
		}
	}
	for _, v := range b {
		if !bindaddrSliceContains(a, v) {
			return false
		}
	}
	return true
}

func TestGetServerBindaddrs(t *testing.T) {
	badTests := [...]struct {
		ptServerBindaddr         string
		ptServerTransports       string
		ptServerTransportOptions string
	}{
		// bad TOR_PT_SERVER_BINDADDR
		{
			"alpha",
			"alpha",
			"",
		},
		{
			"alpha-1.2.3.4",
			"alpha",
			"",
		},
		// missing TOR_PT_SERVER_TRANSPORTS
		{
			"alpha-1.2.3.4:1111",
			"",
			"alpha:key=value",
		},
		// bad TOR_PT_SERVER_TRANSPORT_OPTIONS
		{
			"alpha-1.2.3.4:1111",
			"alpha",
			"key=value",
		},
		// no escaping is defined for TOR_PT_SERVER_TRANSPORTS or
		// TOR_PT_SERVER_BINDADDR.
		{
			`alpha\,beta-1.2.3.4:1111`,
			`alpha\,beta`,
			"",
		},
	}
	goodTests := [...]struct {
		ptServerBindaddr         string
		ptServerTransports       string
		ptServerTransportOptions string
		expected                 []Bindaddr
	}{
		{
			"alpha-1.2.3.4:1111,beta-[1:2::3:4]:2222",
			"alpha,beta,gamma",
			"alpha:k1=v1,beta:k2=v2,gamma:k3=v3",
			[]Bindaddr{
				{"alpha", &net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 1111}, Args{"k1": []string{"v1"}}},
				{"beta", &net.TCPAddr{IP: net.ParseIP("1:2::3:4"), Port: 2222}, Args{"k2": []string{"v2"}}},
			},
		},
		{
			"alpha-1.2.3.4:1111",
			"xxx",
			"",
			[]Bindaddr{},
		},
		{
			"alpha-1.2.3.4:1111",
			"alpha,beta,gamma",
			"",
			[]Bindaddr{
				{"alpha", &net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 1111}, Args{}},
			},
		},
		{
			"trebuchet-127.0.0.1:1984,ballista-127.0.0.1:4891",
			"trebuchet,ballista",
			"trebuchet:secret=nou;trebuchet:cache=/tmp/cache;ballista:secret=yes",
			[]Bindaddr{
				{"trebuchet", &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 1984}, Args{"secret": []string{"nou"}, "cache": []string{"/tmp/cache"}}},
				{"ballista", &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 4891}, Args{"secret": []string{"yes"}}},
			},
		},
		// In the past, "*" meant to return all known transport names.
		// But now it has no special meaning.
		// https://trac.torproject.org/projects/tor/ticket/15612
		{
			"alpha-1.2.3.4:1111,beta-[1:2::3:4]:2222",
			"*",
			"",
			[]Bindaddr{},
		},
	}

	Stdout = ioutil.Discard

	os.Clearenv()
	_, err := getServerBindaddrs()
	if err == nil {
		t.Errorf("empty environment unexpectedly succeeded")
	}

	for _, test := range badTests {
		os.Setenv("TOR_PT_SERVER_BINDADDR", test.ptServerBindaddr)
		os.Setenv("TOR_PT_SERVER_TRANSPORTS", test.ptServerTransports)
		os.Setenv("TOR_PT_SERVER_TRANSPORT_OPTIONS", test.ptServerTransportOptions)
		_, err := getServerBindaddrs()
		if err == nil {
			t.Errorf("TOR_PT_SERVER_BINDADDR=%q TOR_PT_SERVER_TRANSPORTS=%q TOR_PT_SERVER_TRANSPORT_OPTIONS=%q unexpectedly succeeded",
				test.ptServerBindaddr, test.ptServerTransports, test.ptServerTransportOptions)
		}
	}

	for _, test := range goodTests {
		os.Setenv("TOR_PT_SERVER_BINDADDR", test.ptServerBindaddr)
		os.Setenv("TOR_PT_SERVER_TRANSPORTS", test.ptServerTransports)
		os.Setenv("TOR_PT_SERVER_TRANSPORT_OPTIONS", test.ptServerTransportOptions)
		output, err := getServerBindaddrs()
		if err != nil {
			t.Errorf("TOR_PT_SERVER_BINDADDR=%q TOR_PT_SERVER_TRANSPORTS=%q TOR_PT_SERVER_TRANSPORT_OPTIONS=%q unexpectedly returned an error: %s",
				test.ptServerBindaddr, test.ptServerTransports, test.ptServerTransportOptions, err)
		}
		if !bindaddrSetsEqual(output, test.expected) {
			t.Errorf("TOR_PT_SERVER_BINDADDR=%q TOR_PT_SERVER_TRANSPORTS=%q TOR_PT_SERVER_TRANSPORT_OPTIONS=%q → %q (expected %q)",
				test.ptServerBindaddr, test.ptServerTransports, test.ptServerTransportOptions, output, test.expected)
		}
	}
}

func TestReadAuthCookie(t *testing.T) {
	badTests := [...][]byte{
		[]byte(""),
		// bad header
		[]byte("! Impostor ORPort Auth Cookie !\x0a0123456789ABCDEF0123456789ABCDEF"),
		// too short
		[]byte("! Extended ORPort Auth Cookie !\x0a0123456789ABCDEF0123456789ABCDE"),
		// too long
		[]byte("! Extended ORPort Auth Cookie !\x0a0123456789ABCDEF0123456789ABCDEFX"),
	}
	goodTests := [...][]byte{
		[]byte("! Extended ORPort Auth Cookie !\x0a0123456789ABCDEF0123456789ABCDEF"),
	}

	for _, input := range badTests {
		var buf bytes.Buffer
		buf.Write(input)
		_, err := readAuthCookie(&buf)
		if err == nil {
			t.Errorf("%q unexpectedly succeeded", input)
		}
	}

	for _, input := range goodTests {
		var buf bytes.Buffer
		buf.Write(input)
		cookie, err := readAuthCookie(&buf)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", input, err)
		}
		if !bytes.Equal(cookie, input[32:64]) {
			t.Errorf("%q → %q (expected %q)", input, cookie, input[:32])
		}
	}
}

func TestComputeServerHash(t *testing.T) {
	authCookie := make([]byte, 32)
	clientNonce := make([]byte, 32)
	serverNonce := make([]byte, 32)
	// hmac.new("\x00"*32, "ExtORPort authentication server-to-client hash" + "\x00"*64, hashlib.sha256).hexdigest()
	expected := []byte("\x9e\x22\x19\x19\x98\x2a\x84\xf7\x5f\xaf\x60\xef\x92\x69\x49\x79\x62\x68\xc9\x78\x33\xe0\x69\x60\xff\x26\x53\x69\xa9\x0f\xd6\xd8")
	hash := computeServerHash(authCookie, clientNonce, serverNonce)
	if !bytes.Equal(hash, expected) {
		t.Errorf("%x %x %x → %x (expected %x)", authCookie,
			clientNonce, serverNonce, hash, expected)
	}
}

func TestComputeClientHash(t *testing.T) {
	authCookie := make([]byte, 32)
	clientNonce := make([]byte, 32)
	serverNonce := make([]byte, 32)
	// hmac.new("\x00"*32, "ExtORPort authentication client-to-server hash" + "\x00"*64, hashlib.sha256).hexdigest()
	expected := []byte("\x0f\x36\x8b\x1b\xee\x24\xaa\xbc\x54\xa9\x11\x4c\xe0\x6c\x07\x0f\x3e\xd9\x9d\x0d\x36\x8f\x59\x9c\xcc\x6d\xfd\xc8\xbf\x45\x7a\x62")
	hash := computeClientHash(authCookie, clientNonce, serverNonce)
	if !bytes.Equal(hash, expected) {
		t.Errorf("%x %x %x → %x (expected %x)", authCookie,
			clientNonce, serverNonce, hash, expected)
	}
}

// Elide a byte slice in case it's really long.
func fmtBytes(s []byte) string {
	if len(s) > 100 {
		return fmt.Sprintf("%q...(%d bytes)", s[:5], len(s))
	} else {
		return fmt.Sprintf("%q", s)
	}
}

func TestExtOrSendCommand(t *testing.T) {
	badTests := [...]struct {
		cmd  uint16
		body []byte
	}{
		{0x0, make([]byte, 65536)},
		{0x1234, make([]byte, 65536)},
	}
	longBody := [65535 + 2 + 2]byte{0x12, 0x34, 0xff, 0xff}
	goodTests := [...]struct {
		cmd      uint16
		body     []byte
		expected []byte
	}{
		{0x0, []byte(""), []byte("\x00\x00\x00\x00")},
		{0x5, []byte(""), []byte("\x00\x05\x00\x00")},
		{0xfffe, []byte(""), []byte("\xff\xfe\x00\x00")},
		{0xffff, []byte(""), []byte("\xff\xff\x00\x00")},
		{0x1234, []byte("hello"), []byte("\x12\x34\x00\x05hello")},
		{0x1234, make([]byte, 65535), longBody[:]},
	}

	for _, test := range badTests {
		var buf bytes.Buffer
		err := extOrPortSendCommand(&buf, test.cmd, test.body)
		if err == nil {
			t.Errorf("0x%04x %s unexpectedly succeeded", test.cmd, fmtBytes(test.body))
		}
	}

	for _, test := range goodTests {
		var buf bytes.Buffer
		err := extOrPortSendCommand(&buf, test.cmd, test.body)
		if err != nil {
			t.Errorf("0x%04x %s unexpectedly returned an error: %s", test.cmd, fmtBytes(test.body), err)
		}
		p := make([]byte, 65535+2+2)
		n, err := buf.Read(p)
		if err != nil {
			t.Fatal(err)
		}
		output := p[:n]
		if !bytes.Equal(output, test.expected) {
			t.Errorf("0x%04x %s → %s (expected %s)", test.cmd, fmtBytes(test.body),
				fmtBytes(output), fmtBytes(test.expected))
		}
	}
}

func TestExtOrSendUserAddr(t *testing.T) {
	addrs := [...]string{
		"0.0.0.0:0",
		"1.2.3.4:9999",
		"255.255.255.255:65535",
		"[::]:0",
		"[ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255]:63335",
	}

	for _, addr := range addrs {
		var buf bytes.Buffer
		err := extOrPortSendUserAddr(&buf, addr)
		if err != nil {
			t.Errorf("%s unexpectedly returned an error: %s", addr, err)
		}
		var cmd, length uint16
		binary.Read(&buf, binary.BigEndian, &cmd)
		if cmd != extOrCmdUserAddr {
			t.Errorf("%s → cmd 0x%04x (expected 0x%04x)", addr, cmd, extOrCmdUserAddr)
		}
		binary.Read(&buf, binary.BigEndian, &length)
		p := make([]byte, length+1)
		n, err := buf.Read(p)
		if n != int(length) {
			t.Errorf("%s said length %d but had at least %d", addr, length, n)
		}
		// test that parsing the address gives something equivalent to
		// parsing the original.
		inputAddr, err := resolveAddr(addr)
		if err != nil {
			t.Fatal(err)
		}
		outputAddr, err := resolveAddr(string(p[:n]))
		if err != nil {
			t.Fatal(err)
		}
		if !tcpAddrsEqual(inputAddr, outputAddr) {
			t.Errorf("%s → %s", addr, outputAddr)
		}
	}
}

func TestExtOrPortSendTransport(t *testing.T) {
	tests := [...]struct {
		methodName string
		expected   []byte
	}{
		{"", []byte("\x00\x02\x00\x00")},
		{"a", []byte("\x00\x02\x00\x01a")},
		{"alpha", []byte("\x00\x02\x00\x05alpha")},
	}

	for _, test := range tests {
		var buf bytes.Buffer
		err := extOrPortSendTransport(&buf, test.methodName)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", test.methodName, err)
		}
		p := make([]byte, 1024)
		n, err := buf.Read(p)
		if err != nil {
			t.Fatal(err)
		}
		output := p[:n]
		if !bytes.Equal(output, test.expected) {
			t.Errorf("%q → %s (expected %s)", test.methodName,
				fmtBytes(output), fmtBytes(test.expected))
		}
	}
}

func TestExtOrPortSendDone(t *testing.T) {
	expected := []byte("\x00\x00\x00\x00")

	var buf bytes.Buffer
	err := extOrPortSendDone(&buf)
	if err != nil {
		t.Errorf("unexpectedly returned an error: %s", err)
	}
	p := make([]byte, 1024)
	n, err := buf.Read(p)
	if err != nil {
		t.Fatal(err)
	}
	output := p[:n]
	if !bytes.Equal(output, expected) {
		t.Errorf("→ %s (expected %s)", fmtBytes(output), fmtBytes(expected))
	}
}

func TestExtOrPortRecvCommand(t *testing.T) {
	badTests := [...][]byte{
		[]byte(""),
		[]byte("\x12"),
		[]byte("\x12\x34"),
		[]byte("\x12\x34\x00"),
		[]byte("\x12\x34\x00\x01"),
	}
	goodTests := [...]struct {
		input    []byte
		cmd      uint16
		body     []byte
		leftover []byte
	}{
		{
			[]byte("\x12\x34\x00\x00"),
			0x1234, []byte(""), []byte(""),
		},
		{
			[]byte("\x12\x34\x00\x00more"),
			0x1234, []byte(""), []byte("more"),
		},
		{
			[]byte("\x12\x34\x00\x04body"),
			0x1234, []byte("body"), []byte(""),
		},
		{
			[]byte("\x12\x34\x00\x04bodymore"),
			0x1234, []byte("body"), []byte("more"),
		},
	}

	for _, input := range badTests {
		var buf bytes.Buffer
		buf.Write(input)
		_, _, err := extOrPortRecvCommand(&buf)
		if err == nil {
			t.Errorf("%q unexpectedly succeeded", fmtBytes(input))
		}
	}

	for _, test := range goodTests {
		var buf bytes.Buffer
		buf.Write(test.input)
		cmd, body, err := extOrPortRecvCommand(&buf)
		if err != nil {
			t.Errorf("%s unexpectedly returned an error: %s", fmtBytes(test.input), err)
		}
		if cmd != test.cmd {
			t.Errorf("%s → cmd 0x%04x (expected 0x%04x)", fmtBytes(test.input), cmd, test.cmd)
		}
		if !bytes.Equal(body, test.body) {
			t.Errorf("%s → body %s (expected %s)", fmtBytes(test.input),
				fmtBytes(body), fmtBytes(test.body))
		}
		p := make([]byte, 1024)
		n, err := buf.Read(p)
		if err != nil && err != io.EOF {
			t.Fatal(err)
		}
		leftover := p[:n]
		if !bytes.Equal(leftover, test.leftover) {
			t.Errorf("%s → leftover %s (expected %s)", fmtBytes(test.input),
				fmtBytes(leftover), fmtBytes(test.leftover))
		}
	}
}

// set up so that extOrPortSetup can write to one buffer and read from another.
type mockSetupBuf struct {
	bytes.Buffer
	ReadBuf bytes.Buffer
}

func (buf *mockSetupBuf) Read(p []byte) (int, error) {
	n, err := buf.ReadBuf.Read(p)
	return n, err
}

func testExtOrPortSetupIndividual(t *testing.T, addr, methodName string) {
	var err error
	var buf mockSetupBuf
	// fake an OKAY response.
	err = extOrPortSendCommand(&buf.ReadBuf, extOrCmdOkay, []byte{})
	if err != nil {
		t.Fatal(err)
	}
	err = extOrPortSetup(&buf, addr, methodName)
	if err != nil {
		t.Fatalf("error in extOrPortSetup: %s", err)
	}
	for {
		cmd, body, err := extOrPortRecvCommand(&buf.Buffer)
		if err != nil {
			t.Fatalf("error in extOrPortRecvCommand: %s", err)
		}
		if cmd == extOrCmdDone {
			break
		}
		if addr != "" && cmd == extOrCmdUserAddr {
			if string(body) != addr {
				t.Errorf("addr=%q methodName=%q got USERADDR with body %q (expected %q)", addr, methodName, body, addr)
			}
			continue
		}
		if methodName != "" && cmd == extOrCmdTransport {
			if string(body) != methodName {
				t.Errorf("addr=%q methodName=%q got TRANSPORT with body %q (expected %q)", addr, methodName, body, methodName)
			}
			continue
		}
		t.Errorf("addr=%q methodName=%q got unknown cmd %d body %q", addr, methodName, cmd, body)
	}
}

func TestExtOrPortSetup(t *testing.T) {
	const addr = "127.0.0.1:40000"
	const methodName = "alpha"
	testExtOrPortSetupIndividual(t, "", "")
	testExtOrPortSetupIndividual(t, addr, "")
	testExtOrPortSetupIndividual(t, "", methodName)
	testExtOrPortSetupIndividual(t, addr, methodName)
}

func TestMakeStateDir(t *testing.T) {
	os.Clearenv()

	// TOR_PT_STATE_LOCATION not set.
	_, err := MakeStateDir()
	if err == nil {
		t.Errorf("empty environment unexpectedly succeeded")
	}

	// Setup the scratch directory.
	tempDir, err := ioutil.TempDir("", "testMakeStateDir")
	if err != nil {
		t.Fatalf("ioutil.TempDir failed: %s", err)
	}
	defer os.RemoveAll(tempDir)

	goodTests := [...]string{
		// Already existing directory.
		tempDir,

		// Nonexistent directory, parent exists.
		path.Join(tempDir, "parentExists"),

		// Nonexistent directory, parent doesn't exist.
		path.Join(tempDir, "missingParent", "parentMissing"),
	}
	for _, test := range goodTests {
		os.Setenv("TOR_PT_STATE_LOCATION", test)
		dir, err := MakeStateDir()
		if err != nil {
			t.Errorf("MakeStateDir unexpectedly failed: %s", err)
		}
		if dir != test {
			t.Errorf("MakeStateDir returned an unexpected path %s (expecting %s)", dir, test)
		}
	}

	// Name already exists, but is an ordinary file.
	tempFile := path.Join(tempDir, "file")
	f, err := os.Create(tempFile)
	if err != nil {
		t.Fatalf("os.Create failed: %s", err)
	}
	defer f.Close()
	os.Setenv("TOR_PT_STATE_LOCATION", tempFile)
	_, err = MakeStateDir()
	if err == nil {
		t.Errorf("MakeStateDir with a file unexpectedly succeeded")
	}

	// Directory name that cannot be created. (Subdir of a file)
	os.Setenv("TOR_PT_STATE_LOCATION", path.Join(tempFile, "subDir"))
	_, err = MakeStateDir()
	if err == nil {
		t.Errorf("MakeStateDir with a subdirectory of a file unexpectedly succeeded")
	}
}
