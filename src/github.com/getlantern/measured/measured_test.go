package measured

import (
	"net"
	"net/http"
	"runtime"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

type mockReporter struct {
	error   map[Error]int
	latency []*LatencyTracker
	traffic []*TrafficTracker
}

func (nr *mockReporter) ReportError(e map[*Error]int) error {
	for k, v := range e {
		nr.error[*k] = v
	}
	return nil
}

func (nr *mockReporter) ReportLatency(l []*LatencyTracker) error {
	nr.latency = append(nr.latency, l...)
	return nil
}

func (nr *mockReporter) ReportTraffic(t []*TrafficTracker) error {
	nr.traffic = append(nr.traffic, t...)
	return nil
}

func TestReportError(t *testing.T) {
	nr := startWithMockReporter()
	defer Stop()
	d := Dialer(net.Dial, 10*time.Second)
	_, _ = d("tcp", "localhost:9999")
	_, _ = d("tcp", "localhost:9998")
	runtime.Gosched()
	time.Sleep(100 * time.Millisecond)
	if assert.Equal(t, 2, len(nr.error)) {
		assert.Equal(t, 1, nr.error[Error{"localhost:9999", "connection refused", "dial"}])
		assert.Equal(t, 1, nr.error[Error{"localhost:9998", "connection refused", "dial"}])
	}
}

func TestReportStats(t *testing.T) {
	nr := startWithMockReporter()
	defer Stop()
	var bytesIn, bytesOut uint64
	var RemoteAddr string

	// start server with byte counting
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if assert.NoError(t, err, "Listen should not fail") {
		// large enough interval so it will only report stats in Close()
		ml := Listener(l, 10*time.Second)
		s := http.Server{
			Handler: http.NotFoundHandler(),
			ConnState: func(c net.Conn, s http.ConnState) {
				if s == http.StateIdle {
					RemoteAddr = c.RemoteAddr().String()
					mc := c.(*Conn)
					bytesIn = mc.BytesIn
					bytesOut = mc.BytesOut
					time.Sleep(100 * time.Millisecond)
					_ = mc.Close()
				}
			},
		}
		go func() { _ = s.Serve(ml) }()
	}

	// start client with byte counting
	c := http.Client{
		Transport: &http.Transport{
			// carefully chosen interval to report another once before Close()
			Dial: Dialer(net.Dial, 160*time.Millisecond),
		},
	}
	req, _ := http.NewRequest("GET", "http://"+l.Addr().String(), nil)
	resp, _ := c.Do(req)
	assert.Equal(t, 404, resp.StatusCode)
	_ = resp.Body.Close()
	assert.True(t, bytesIn > 0, "should count bytesIn")
	assert.True(t, bytesOut > 0, "should count bytesOut")

	time.Sleep(300 * time.Millisecond)
	// verify both client and server stats
	if assert.Equal(t, 3, len(nr.traffic)) {
		e := nr.traffic[1]
		assert.Equal(t, RemoteAddr, e.ID, "should report server stats with Remote addr")
		assert.Equal(t, bytesIn, e.TotalIn, "should report server stats with bytes in")
		assert.Equal(t, bytesOut, e.TotalOut, "should report server stats with bytes out")
		assert.Equal(t, bytesIn, e.MinIn, "should report server stats with bytes in")
		assert.Equal(t, bytesOut, e.MinOut, "should report server stats with bytes out")

		e = nr.traffic[0]
		assert.Equal(t, l.Addr().String(), e.ID, "should report server as Remote addr")
		assert.Equal(t, bytesIn, e.MinOut, "should report same byte count as server")
		assert.Equal(t, bytesOut, e.MinIn, "should report same byte count as server")

		e = nr.traffic[2]
		assert.Equal(t, l.Addr().String(), e.ID, "should report server as Remote addr")
		assert.Equal(t, uint64(0), e.MinOut, "should only report increased byte count")
		assert.Equal(t, uint64(0), e.MinIn, "should only report increased byte count")
	}
}

func startWithMockReporter() *mockReporter {
	nr := mockReporter{
		error: make(map[Error]int),
	}
	Start(50*time.Millisecond, &nr)
	// To make sure it really started
	runtime.Gosched()
	return &nr
}
