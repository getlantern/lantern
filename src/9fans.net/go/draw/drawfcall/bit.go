package drawfcall // import "9fans.net/go/draw/drawfcall"

// Note that these are big-endian, unlike Plan 9 fcalls, which are little-endian.

func gbit8(b []byte) (uint8, []byte) {
	return uint8(b[0]), b[1:]
}

func gbit16(b []byte) (uint16, []byte) {
	return uint16(b[1]) | uint16(b[0])<<8, b[2:]
}

func gbit32(b []byte) (int, []byte) {
	return int(uint32(b[3]) | uint32(b[2])<<8 | uint32(b[1])<<16 | uint32(b[0])<<24), b[4:]
}

func gbit64(b []byte) (uint64, []byte) {
	hi, b := gbit32(b)
	lo, b := gbit32(b)
	return uint64(hi)<<32 | uint64(lo), b
}

func gstring(b []byte) (string, []byte) {
	n, b := gbit32(b)
	return string(b[0:n]), b[n:]
}

func gbytes(b []byte) ([]byte, []byte) {
	n, b := gbit32(b)
	return b[0:n], b[n:]
}

func pbit8(b []byte, x uint8) []byte {
	n := len(b)
	if n+1 > cap(b) {
		nb := make([]byte, n, 100+2*cap(b))
		copy(nb, b)
		b = nb
	}
	b = b[0 : n+1]
	b[n] = x
	return b
}

func pbit16(b []byte, x uint16) []byte {
	n := len(b)
	if n+2 > cap(b) {
		nb := make([]byte, n, 100+2*cap(b))
		copy(nb, b)
		b = nb
	}
	b = b[0 : n+2]
	b[n] = byte(x >> 8)
	b[n+1] = byte(x)
	return b
}

func pbit32(b []byte, i int) []byte {
	x := uint32(i)
	n := len(b)
	if n+4 > cap(b) {
		nb := make([]byte, n, 100+2*cap(b))
		copy(nb, b)
		b = nb
	}
	b = b[0 : n+4]
	b[n] = byte(x >> 24)
	b[n+1] = byte(x >> 16)
	b[n+2] = byte(x >> 8)
	b[n+3] = byte(x)
	return b
}

func pbit64(b []byte, x uint64) []byte {
	b = pbit32(b, int(x>>32))
	b = pbit32(b, int(x))
	return b
}

func pstring(b []byte, s string) []byte {
	b = pbit32(b, len(s))
	b = append(b, []byte(s)...)
	return b
}

func pbytes(b, s []byte) []byte {
	b = pbit32(b, len(s))
	b = append(b, s...)
	return b
}
