// +build integration_test

package borda

import (
	"fmt"
	"math/rand"
	"os/exec"
	"testing"
	"time"

	"github.com/golang/glog"

	"github.com/stretchr/testify/assert"
)

const (
	numProxies       = 100
	numClients       = 1000
	proxiesPerClient = 2
)

func init() {
	// Always use the same random seed
	rand.Seed(1)
}

// TestRealWorldScenario simulates real-world scenarios of clients and servers.
func TestRealWorldScenario(t *testing.T) {
	// Drop the database
	out, err := exec.Command("./drop_database.bash").Output()
	if err != nil {
		glog.Errorf("Unable to drop database: %v", string(out))
	}

	write, err := InfluxWriter("http://localhost:8086", "test", "test")
	if !assert.NoError(t, err, "Unable to create InfluxWriter") {
		return
	}

	c := NewCollector(&Options{
		IndexedDimensions: []string{"request_id", "client_error", "proxy_error", "client", "proxy", "browser", "os", "os_version", "client_version", "randomserverthing"},
		WriteToDatabase:   write,
		DBName:            "lantern",
		BatchSize:         1000,
		MaxBatchWindow:    30 * time.Second,
		MaxRetries:        100,
		RetryInterval:     250 * time.Millisecond,
	})

	// Create the database
	out, err = exec.Command("./create_database.bash").Output()
	if !assert.NoError(t, err, "Unable to create database: %v", string(out)) {
		return
	}

	// Wait for continuous queries to initialize
	time.Sleep(5 * time.Second)

	// Simulate some clients and proxies
	proxies := make([]*proxy, 0, numProxies)
	for i := 0; i < numProxies; i++ {
		proxy := &proxy{
			c:       c,
			ip:      fmt.Sprintf("43.25.23.%d", i),
			loadAvg: float64(i%18) * 0.05, // bias the loadAvg
		}
		go proxy.run()
		proxies = append(proxies, proxy)
	}

	for i := 0; i < numClients; i++ {
		clientProxies := make([]*proxy, 0, proxiesPerClient)
		for j := 0; j < proxiesPerClient; j++ {
			clientProxies = append(clientProxies, proxies[(i+j)%numProxies])
		}
		go runClient(fmt.Sprintf("client_%d", i), c, clientProxies)
	}

	// Wait for some data to get generated
	time.Sleep(5 * time.Minute)

	out, err = exec.Command("./drop_cqs.bash").Output()
	assert.NoError(t, err, "Unable to drop continuous queries: %v", string(out))

	out, err = exec.Command("./query.bash").Output()
	if assert.NoError(t, err, "Unable to run queries: %v", string(out)) {
		t.Log(string(out))
	}
}

const (
	result_ok              = iota
	result_none            = iota
	result_mimic_apache    = iota
	result_error           = iota
	result_connect_timeout = iota
)

type request struct {
	client string
	result chan int
}

type proxy struct {
	c        Collector
	ip       string
	requests chan *request
	loadAvg  float64
}

func (p *proxy) run() {
	p.requests = make(chan *request)
	p.updateLoadAvg()
	loadAvgInterval := 5 * time.Second
	timer := time.NewTimer(loadAvgInterval)
	for {
		select {
		case req := <-p.requests:
			if p.loadAvg > 0.9 && rand.Float64() > 0.5 {
				// Simulate no response
				req.result <- result_none
			} else if rand.Float64() > 0.99 {
				// Simulate error connecting downstream
				req.result <- result_error
				p.c.Submit(&Measurement{
					Name: "proxy_results",
					Ts:   time.Now(),
					Values: map[string]float64{
						"proxy_error_count": 1,
					},
					Dimensions: map[string]interface{}{
						"proxy_error":       "OriginConnectTimeout",
						"client":            req.client,
						"proxy":             p.ip,
						"randomserverthing": rand.Intn(10),
					},
				})
			} else if rand.Float64() > 0.99 {
				// Simulate missing token
				req.result <- result_mimic_apache
				p.c.Submit(&Measurement{
					Name: "proxy_results",
					Ts:   time.Now(),
					Values: map[string]float64{
						"proxy_error_count": 1,
					},
					Dimensions: map[string]interface{}{
						"proxy_error":       "MissingAuthToken",
						"client":            req.client,
						"proxy":             p.ip,
						"randomserverthing": rand.Intn(10),
					},
				})
			} else if rand.Float64() > 0.99 {
				// Simulate timeout by doing nothing
			} else {
				req.result <- result_ok
				p.c.Submit(&Measurement{
					Name: "proxy_results",
					Ts:   time.Now(),
					Values: map[string]float64{
						"proxy_success_count": 1,
					},
					Dimensions: map[string]interface{}{
						"client":            req.client,
						"proxy":             p.ip,
						"randomserverthing": rand.Intn(10),
					},
				})
			}
		case <-timer.C:
			p.updateLoadAvg()
			timer.Reset(loadAvgInterval)
		}
	}
}

func (p *proxy) updateLoadAvg() {
	// Simulate random walk of loadAvg
	delta := (0.5 - rand.Float64()) / 10
	p.loadAvg = p.loadAvg + delta
	if p.loadAvg < 0 {
		p.loadAvg = 0
	}
	p.c.Submit(&Measurement{
		Name: "proxy_health",
		Ts:   time.Now(),
		Values: map[string]float64{
			"load_avg": p.loadAvg,
		},
		Dimensions: map[string]interface{}{
			"proxy": p.ip,
		},
	})
}

func runClient(id string, c Collector, proxies []*proxy) {
	resultCodesToErrorCodes := map[int]string{
		result_none:         "ChainedServerTimeout",
		result_error:        "ChainedServerError",
		result_mimic_apache: "ChainedServerError",
	}
	resultCounts := make(map[string]map[int]int)
	recordResult := func(proxy *proxy, result int) {
		countsForProxy := resultCounts[proxy.ip]
		if countsForProxy == nil {
			countsForProxy = make(map[int]int)
			resultCounts[proxy.ip] = countsForProxy
		}
		countsForProxy[result] = countsForProxy[result] + 1
	}

	reportingInterval := 30 * time.Second
	reportTimer := time.NewTimer(reportingInterval)
	for {
		select {
		case <-time.After(time.Duration(rand.Intn(200)) * time.Millisecond):
			// Simulate a request
			proxy := proxies[rand.Intn(len(proxies))]
			req := &request{
				client: id,
				result: make(chan int),
			}
			proxy.requests <- req
			select {
			case result := <-req.result:
				recordResult(proxy, result)
			case <-time.After(25 * time.Millisecond):
				recordResult(proxy, result_connect_timeout)
			}
		case <-reportTimer.C:
			// Simulate pre-aggregated reporting of results
			for ip, countsForProxy := range resultCounts {
				for result, count := range countsForProxy {
					m := &Measurement{
						Name:   "client_results",
						Ts:     time.Now(),
						Values: map[string]float64{},
						Dimensions: map[string]interface{}{
							"client":         id,
							"proxy":          ip,
							"browser":        "chrome",
							"os":             "windows",
							"os_version":     7 + rand.Intn(3),
							"client_version": fmt.Sprintf("2.2.%d", rand.Intn(9)),
						},
					}
					if result == result_ok {
						m.Values["client_success_count"] = float64(count)
					} else {
						m.Values["client_error_count"] = float64(count)
						m.Dimensions["client_error"] = resultCodesToErrorCodes[result]
					}
					c.Submit(m)
				}
			}
		}
	}
}
