package pool

type SingleConnPool struct {
	cn *Conn
}

var _ Pooler = (*SingleConnPool)(nil)

func NewSingleConnPool(cn *Conn) *SingleConnPool {
	return &SingleConnPool{
		cn: cn,
	}
}

func (p *SingleConnPool) First() *Conn {
	return p.cn
}

func (p *SingleConnPool) Get() (*Conn, error) {
	return p.cn, nil
}

func (p *SingleConnPool) Put(cn *Conn) error {
	if p.cn != cn {
		panic("p.cn != cn")
	}
	return nil
}

func (p *SingleConnPool) Remove(cn *Conn, _ error) error {
	if p.cn != cn {
		panic("p.cn != cn")
	}
	return nil
}

func (p *SingleConnPool) Len() int {
	return 1
}

func (p *SingleConnPool) FreeLen() int {
	return 0
}

func (p *SingleConnPool) Stats() *PoolStats {
	return nil
}

func (p *SingleConnPool) Close() error {
	return nil
}

func (p *SingleConnPool) Closed() bool {
	return false
}
