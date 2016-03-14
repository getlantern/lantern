package detour

type detourConn struct {
}

func (conn *detourConn) Dial(network, addr string) (ch chan struct{}) {
	return nil
}

func (dc *detourConn) Read(b []byte) chan ioResult {
	ch := make(chan ioResult)
	return ch
}

func (dc *detourConn) Write(b []byte) chan ioResult {
	ch := make(chan ioResult)
	return ch
}

func (dc *detourConn) Close() (err error) {
	return nil
}
