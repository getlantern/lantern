package client // import "9fans.net/go/plan9/client"

import (
	"fmt"
	"io"
	"sync"

	"9fans.net/go/plan9"
)

type Error string

func (e Error) Error() string { return string(e) }

type Conn struct {
	rwc     io.ReadWriteCloser
	err     error
	tagmap  map[uint16]chan *plan9.Fcall
	freetag map[uint16]bool
	freefid map[uint32]bool
	nexttag uint16
	nextfid uint32
	msize   uint32
	version string
	r, w, x sync.Mutex
	muxer   bool
}

func NewConn(rwc io.ReadWriteCloser) (*Conn, error) {
	c := &Conn{
		rwc:     rwc,
		tagmap:  make(map[uint16]chan *plan9.Fcall),
		freetag: make(map[uint16]bool),
		freefid: make(map[uint32]bool),
		nexttag: 1,
		nextfid: 1,
		msize:   131072,
		version: "9P2000",
	}

	//	XXX raw messages, not c.rpc
	tx := &plan9.Fcall{Type: plan9.Tversion, Msize: c.msize, Version: c.version}
	rx, err := c.rpc(tx)
	if err != nil {
		return nil, err
	}

	if rx.Msize > c.msize {
		return nil, plan9.ProtocolError(fmt.Sprintf("invalid msize %d in Rversion", rx.Msize))
	}
	c.msize = rx.Msize
	if rx.Version != "9P2000" {
		return nil, plan9.ProtocolError(fmt.Sprintf("invalid version %s in Rversion", rx.Version))
	}
	return c, nil
}

func (c *Conn) newfid() (*Fid, error) {
	c.x.Lock()
	defer c.x.Unlock()
	var fidnum uint32
	for fidnum, _ = range c.freefid {
		delete(c.freefid, fidnum)
		goto found
	}
	fidnum = c.nextfid
	if c.nextfid == plan9.NOFID {
		return nil, plan9.ProtocolError("out of fids")
	}
	c.nextfid++
found:
	return &Fid{fid: fidnum, c: c}, nil
}

func (c *Conn) putfid(f *Fid) {
	c.x.Lock()
	defer c.x.Unlock()
	if f.fid != 0 && f.fid != plan9.NOFID {
		c.freefid[f.fid] = true
		f.fid = plan9.NOFID
	}
}

func (c *Conn) newtag(ch chan *plan9.Fcall) (uint16, error) {
	c.x.Lock()
	defer c.x.Unlock()
	var tagnum uint16
	for tagnum, _ = range c.freetag {
		delete(c.freetag, tagnum)
		goto found
	}
	tagnum = c.nexttag
	if c.nexttag == plan9.NOTAG {
		return 0, plan9.ProtocolError("out of tags")
	}
	c.nexttag++
found:
	c.tagmap[tagnum] = ch
	if !c.muxer {
		c.muxer = true
		ch <- &yourTurn
	}
	return tagnum, nil
}

func (c *Conn) puttag(tag uint16) chan *plan9.Fcall {
	c.x.Lock()
	defer c.x.Unlock()
	ch := c.tagmap[tag]
	delete(c.tagmap, tag)
	c.freetag[tag] = true
	return ch
}

func (c *Conn) mux(rx *plan9.Fcall) {
	c.x.Lock()
	defer c.x.Unlock()

	ch := c.tagmap[rx.Tag]
	delete(c.tagmap, rx.Tag)
	c.freetag[rx.Tag] = true
	c.muxer = false
	for _, ch2 := range c.tagmap {
		c.muxer = true
		ch2 <- &yourTurn
		break
	}
	ch <- rx
}

func (c *Conn) read() (*plan9.Fcall, error) {
	if err := c.getErr(); err != nil {
		return nil, err
	}
	f, err := plan9.ReadFcall(c.rwc)
	if err != nil {
		c.setErr(err)
		return nil, err
	}
	return f, nil
}

func (c *Conn) write(f *plan9.Fcall) error {
	if err := c.getErr(); err != nil {
		return err
	}
	err := plan9.WriteFcall(c.rwc, f)
	if err != nil {
		c.setErr(err)
	}
	return err
}

var yourTurn plan9.Fcall

func (c *Conn) rpc(tx *plan9.Fcall) (rx *plan9.Fcall, err error) {
	ch := make(chan *plan9.Fcall, 1)
	tx.Tag, err = c.newtag(ch)
	if err != nil {
		return nil, err
	}
	c.w.Lock()
	if err := c.write(tx); err != nil {
		c.w.Unlock()
		return nil, err
	}
	c.w.Unlock()

	for rx = range ch {
		if rx != &yourTurn {
			break
		}
		rx, err = c.read()
		if err != nil {
			break
		}
		c.mux(rx)
	}

	if rx == nil {
		return nil, c.getErr()
	}
	if rx.Type == plan9.Rerror {
		return nil, Error(rx.Ename)
	}
	if rx.Type != tx.Type+1 {
		return nil, plan9.ProtocolError("packet type mismatch")
	}
	return rx, nil
}

func (c *Conn) Close() error {
	return c.rwc.Close()
}

func (c *Conn) getErr() error {
	c.x.Lock()
	err := c.err
	c.x.Unlock()
	return err
}

func (c *Conn) setErr(err error) {
	c.x.Lock()
	c.err = err
	c.x.Unlock()
}
