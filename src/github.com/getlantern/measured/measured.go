/*
Package measured wraps a dialer/listener to measure the throughput on those
connections. Throughput is represented as total bytes sent/received between each
interval.

ID is the remote address by default.

A list of reporters can be plugged in to send the results to different target.
*/
package measured

import (
	"net"
	"reflect"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

// Traffic encapsulates the traffic data to report
type Traffic struct {
	ID       string
	BytesIn  uint64
	BytesOut uint64
}

// TrafficTracker tracks traffic in single reporting period
type TrafficTracker struct {
	MinIn uint64
	MaxIn uint64
	// Temporarily disabling percentiles since we're not using them. Should we
	// need them, we could use a streaming algorithm to compute them, like this:
	// http://www.cs.rutgers.edu/~muthu/bquant.pdf
	//Percent95In  uint64
	LastIn  uint64
	TotalIn uint64
	MinOut  uint64
	MaxOut  uint64
	//Percent95Out uint64
	LastOut  uint64
	TotalOut uint64
}

// Reporter encapsulates different ways to report statistics
type Reporter interface {
	ReportTraffic(map[string]*TrafficTracker) error
}

type tickingReporter struct {
	t *time.Ticker
	r Reporter
}

// Measured is the controller to report statistics
type Measured struct {
	reporters     []Reporter
	maxBufferSize int
	chTraffic     chan *Traffic
	traffic       map[string]*TrafficTracker
	chStop        chan struct{}
	stopped       int32
	mutex         sync.Mutex
}

var (
	log = golog.LoggerFor("measured")
)

// DialFunc is the type of function measured can wrap
type DialFunc func(net, addr string) (net.Conn, error)

// New creates a new Measured instance
func New(maxBufferSize int) *Measured {
	return &Measured{
		maxBufferSize: maxBufferSize,
		chTraffic:     make(chan *Traffic, maxBufferSize),
		traffic:       make(map[string]*TrafficTracker, maxBufferSize),
		chStop:        make(chan struct{}),
		stopped:       1,
	}
}

// Start runs a new or stopped measured loop
// Reporting interval should be same for all reporters, as cached data should
// be cleared after each round.
func (m *Measured) Start(reportInterval time.Duration, reporters ...Reporter) {
	if atomic.CompareAndSwapInt32(&m.stopped, 1, 0) {
		m.run(reportInterval, reporters...)
	} else {
		log.Debug("measured loop already started")
	}
}

// Stop stops the measured loop
func (m *Measured) Stop() {
	if atomic.CompareAndSwapInt32(&m.stopped, 0, 1) {
		log.Debug("Stopping measured loop...")
		m.chStop <- struct{}{}
	} else {
		log.Debug("Try to stop already stopped measured loop")
	}
}

// Dialer wraps a dial function to measure various statistics
func (m *Measured) Dialer(d DialFunc, interval time.Duration) DialFunc {
	return func(net, addr string) (net.Conn, error) {
		c, err := d(net, addr)
		if err != nil {
			return nil, err
		}
		log.Tracef("Wraping client connection to %s as measured.Conn", addr)
		return m.newConn(c, interval), nil
	}
}

// Listener wraps a listener to measure various statistics of each connection it accepts
func (m *Measured) Listener(l net.Listener, interval time.Duration) *MeasuredListener {
	return &MeasuredListener{m, l, interval}
}

type MeasuredListener struct {
	m *Measured
	net.Listener
	interval time.Duration
}

// Accept wraps the same function of net.Listener to return a connection
// which measures various statistics
func (l *MeasuredListener) Accept() (c net.Conn, err error) {
	c, err = l.Listener.Accept()
	if err != nil {
		return
	}
	log.Tracef("Wrapping server connection to %s as measured.Conn", c.RemoteAddr().String())
	return l.m.newConn(c, l.interval), err
}

func (m *Measured) run(reportInterval time.Duration, reporters ...Reporter) {
	log.Debugf("Measured loop starting with %d reporter(s) and interval %v", len(reporters), reportInterval)
	go m.calculateLoop()
	go m.reportLoop(reportInterval, reporters...)
}

func (m *Measured) calculateLoop() {
	for t := range m.chTraffic {
		if t == nil {
			log.Debug("Calculate loop stopped")
			return
		}
		m.trackTraffic(t.ID, t.BytesIn, t.BytesOut)
	}
}

func (m *Measured) reportLoop(reportInterval time.Duration, reporters ...Reporter) {
	m.reporters = reporters
	t := time.NewTicker(reportInterval)
	for {
		select {
		case <-t.C:
			m.reportTraffic()
		case <-m.chStop:
			log.Debug("Report loop stopped")
			m.chTraffic <- nil
			return
		}
	}
}

func (m *Measured) trackTraffic(id string, in uint64, out uint64) {
	m.mutex.Lock()
	defer m.mutex.Unlock()
	t := m.traffic[id]
	if t == nil {
		if len(m.traffic) >= m.maxBufferSize {
			// Discarding measurement
			return
		}

		// First for this ID
		t = &TrafficTracker{
			MinIn:    in,
			MaxIn:    in,
			LastIn:   in,
			TotalIn:  in,
			MinOut:   out,
			MaxOut:   out,
			LastOut:  out,
			TotalOut: out,
		}
		m.traffic[id] = t
		return
	}

	// Add to existing ID
	if in < t.MinIn {
		t.MinIn = in
	}
	if in > t.MaxIn {
		t.MaxIn = in
	}
	t.LastIn = in
	t.TotalIn += in
	if out < t.MinOut {
		t.MinOut = out
	}
	if out > t.MaxOut {
		t.MaxOut = out
	}
	t.LastOut = out
	t.TotalOut += out
}

func (m *Measured) reportTraffic() {
	m.mutex.Lock()
	currentTraffic := m.traffic
	m.traffic = make(map[string]*TrafficTracker)
	m.mutex.Unlock()
	log.Debugf("Reporting %d traffic entries", len(currentTraffic))
	for _, r := range m.reporters {
		if err := r.ReportTraffic(currentTraffic); err != nil {
			log.Errorf("Failed to report traffic data to %v: %v", reflect.TypeOf(r), err)
		}
	}
}

// Conn wraps any net.Conn to add statistics
type Conn struct {
	net.Conn
	// arbitrary string to identify this connection, defaults to remote address
	ID string
	// total bytes read from this connection
	BytesIn uint64
	// total bytes wrote to this connection
	BytesOut uint64
	// a channel to stop measure and report statistics
	chStop chan struct{}
	m      *Measured
}

func (m *Measured) newConn(c net.Conn, interval time.Duration) net.Conn {
	ra := c.RemoteAddr()
	if ra == nil {
		panic("nil remote address is not allowed")
	}
	mc := &Conn{Conn: c, ID: ra.String(), chStop: make(chan struct{}), m: m}
	ticker := time.NewTicker(interval)
	go func() {
		for {
			select {
			case _ = <-ticker.C:
				mc.submitTraffic()
			case _ = <-mc.chStop:
				ticker.Stop()
				return
			}
		}
	}()
	return mc
}

// Read() implements the function from net.Conn
func (mc *Conn) Read(b []byte) (n int, err error) {
	n, err = mc.Conn.Read(b)
	atomic.AddUint64(&mc.BytesIn, uint64(n))
	return
}

// Write() implements the function from net.Conn
func (mc *Conn) Write(b []byte) (n int, err error) {
	n, err = mc.Conn.Write(b)
	atomic.AddUint64(&mc.BytesOut, uint64(n))
	return
}

// Close implements the function from net.Conn
func (mc *Conn) Close() (err error) {
	err = mc.Conn.Close()
	mc.submitTraffic()
	mc.chStop <- struct{}{}
	return
}

func (mc *Conn) submitTraffic() {
	mc.m.submitTraffic(mc.ID,
		atomic.SwapUint64(&mc.BytesIn, 0),
		atomic.SwapUint64(&mc.BytesOut, 0))
}

func (m *Measured) submitTraffic(connID string, in uint64, out uint64) {
	if atomic.LoadInt32(&m.stopped) == 1 {
		log.Trace("Measured stopped, not submitting traffic")
		return
	}
	t := &Traffic{
		ID:       connID,
		BytesIn:  in,
		BytesOut: out,
	}
	select {
	case m.chTraffic <- t:
		log.Tracef("Submitted traffic %+v", t)
	default:
		log.Tracef("Discarded traffic %+v", t)
	}
}
