package measured

import (
	"net"
	"net/http"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestReportStats(t *testing.T) {
	md, nr := startWithMockReporter()
	defer md.Stop()
	var bytesIn, bytesOut uint64
	var RemoteAddr string

	// start server with byte counting
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if !assert.NoError(t, err, "Listen should not fail") {
		return
	}

	// large enough interval so it will only report stats in Close()
	ml := md.Listener(l, 10*time.Second)
	s := http.Server{
		Handler: http.NotFoundHandler(),
		ConnState: func(c net.Conn, s http.ConnState) {
			if s == http.StateIdle {
				RemoteAddr = c.RemoteAddr().String()
				mc := c.(*Conn)
				atomic.StoreUint64(&bytesIn, mc.BytesIn)
				atomic.StoreUint64(&bytesOut, mc.BytesOut)
			}
		},
	}
	go func() { _ = s.Serve(ml) }()

	time.Sleep(100 * time.Millisecond)
	// start client with byte counting
	c := http.Client{
		Transport: &http.Transport{
			// carefully chosen interval to report another once before Close()
			Dial: md.Dialer(net.Dial, 160*time.Millisecond),
		},
	}
	req, _ := http.NewRequest("GET", "http://"+l.Addr().String(), nil)
	resp, _ := c.Do(req)
	assert.Equal(t, 404, resp.StatusCode)
	assert.True(t, atomic.LoadUint64(&bytesIn) > 0, "should count bytesIn")
	assert.True(t, atomic.LoadUint64(&bytesOut) > 0, "should count bytesOut")

	// make sure client will report another once
	time.Sleep(200 * time.Millisecond)
	// Close without reading from body, to force server to close connection
	_ = resp.Body.Close()
	time.Sleep(100 * time.Millisecond)
	// verify both client and server stats
	nr.Lock()
	defer nr.Unlock()
	t.Logf("Traffic entries: %+v", nr.traffic)
	if assert.Equal(t, 2, len(nr.traffic)) {
		ct := nr.traffic[l.Addr().String()]
		st := nr.traffic[RemoteAddr]

		if assert.NotNil(t, ct) {
			assert.Equal(t, uint64(0), ct.MinOut, "client stats should only report increased byte count")
			assert.Equal(t, uint64(0), ct.MinIn, "client stats should only report increased byte count")
			assert.Equal(t, uint64(0), ct.LastOut, "client stats should only report increased byte count")
			assert.Equal(t, uint64(0), ct.LastIn, "client stats should only report increased byte count")
			assert.Equal(t, uint64(0), ct.TotalOut, "client stats should only report increased byte count")
			assert.Equal(t, uint64(0), ct.TotalIn, "client stats should only report increased byte count")
		}

		if assert.NotNil(t, st) {
			assert.Equal(t, bytesIn, st.TotalIn, "should report server stats with bytes in")
			assert.Equal(t, bytesOut, st.TotalOut, "should report server stats with bytes out")
			assert.Equal(t, bytesIn, st.LastIn, "should report server stats with bytes in")
			assert.Equal(t, bytesOut, st.LastOut, "should report server stats with bytes out")
			assert.Equal(t, bytesIn, st.MinIn, "should report server stats with bytes in")
			assert.Equal(t, bytesOut, st.MinOut, "should report server stats with bytes out")
		}
	}
}

func startWithMockReporter() (*Measured, *mockReporter) {
	nr := mockReporter{
		traffic: make(map[string]*TrafficTracker),
	}
	md := New(50000)
	md.Start(50*time.Millisecond, &nr)
	// To make sure it really started
	runtime.Gosched()
	return md, &nr
}

type mockReporter struct {
	sync.Mutex
	traffic map[string]*TrafficTracker
}

func (nr *mockReporter) ReportTraffic(t map[string]*TrafficTracker) error {
	nr.Lock()
	defer nr.Unlock()
	for key, value := range t {
		nr.traffic[key] = value
	}
	return nil
}
