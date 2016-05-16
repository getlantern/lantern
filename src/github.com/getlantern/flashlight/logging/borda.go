package logging

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"
	"time"

	"github.com/oxtoacart/bpool"

	"github.com/getlantern/flashlight/context"
	"github.com/getlantern/flashlight/proxied"
)

var (
	bordaURL = "https://borda.getlantern.org/measurements"

	bufferPool = bpool.NewBufferPool(100)
)

// Measurement represents a measurement at a point in time. It maps to a "point"
// in InfluxDB.
type Measurement struct {
	// Name is the name of the measurement (e.g. cpu_usage). It maps to the "key"
	// in "InfluxDB".
	Name string `json:"name"`

	// Ts records the time of the measurement.
	Ts time.Time `json:"ts,omitempty"`

	// Fields captures key/value pairs with details of the measurement. It maps to
	// "tags" and "fields" in InfluxDB depending on which fields have been
	// configured as Dimensions on the Collector.
	//
	// Example: { "requestid": "18af517b-004f-486c-9978-6cf60be7f1e9",
	//            "ipv6": "2001:0db8:0a0b:12f0:0000:0000:0000:0001",
	//            "host": "myhost.mydomain.com",
	//            "total_cpus": "2",
	//            "cpu_idle": 10.1,
	//            "cpu_system": 53.3,
	//            "cpu_user": 36.6,
	//            "num_errors": 67,
	//            "connected_to_internet": true }
	Fields json.RawMessage `json:"fields,omitempty"`

	count int
}

type BordaReporterOptions struct {
	ReportInterval time.Duration
	MaxBufferSize  int
}

type BordaReporter struct {
	c       *http.Client
	options *BordaReporterOptions
	buffer  map[string]*Measurement
	mx      sync.Mutex
}

func NewBordaReporter(opts *BordaReporterOptions) *BordaReporter {
	if opts == nil {
		opts = &BordaReporterOptions{}
	}
	if opts.ReportInterval <= 0 {
		log.Debugf("ReportInterval has to be greater than zero, defaulting to 5 minutes")
		opts.ReportInterval = 5 * time.Minute
	}
	if opts.MaxBufferSize <= 0 {
		log.Debugf("MaxBufferSize has to be greater than zero, defaulting to 1000")
		opts.MaxBufferSize = 1000
	}

	rt := proxied.ChainedThenFronted()

	b := &BordaReporter{
		c: &http.Client{
			Transport: proxied.AsRoundTripper(func(req *http.Request) (*http.Response, error) {
				frontedURL := *req.URL
				frontedURL.Host = "d157vud77ygy87.cloudfront.net"
				context.Enter().BackgroundOp("report to borda").Request(req)
				proxied.PrepareForFronting(req, frontedURL.String())
				return rt.RoundTrip(req)
			}),
		},
		options: opts,
		buffer:  make(map[string]*Measurement, opts.MaxBufferSize),
	}

	go b.sendPeriodically()
	return b
}

// Report implements the interface golog.Reporter
func (b *BordaReporter) Report(err error, logText string, ctx map[string]interface{}) {
	fields, encodeErr := json.Marshal(ctx)
	if encodeErr != nil {
		log.Debugf("Unable to encode fields: %v", encodeErr)
		return
	}

	m := &Measurement{
		Name:   "client_error",
		Ts:     time.Now(),
		Fields: fields,
	}

	// Simplistic, non-generic aggregation based on fields
	key := string(fields)
	b.mx.Lock()
	b.addMeasurement(key, m)
	b.mx.Unlock()
}

func (b *BordaReporter) addMeasurement(key string, m *Measurement) {
	existing, found := b.buffer[key]
	if found {
		m.count = existing.count + 1
		if existing.Ts.After(m.Ts) {
			m.Ts = existing.Ts
		}
	} else if len(b.buffer) == b.options.MaxBufferSize {
		log.Debug("Buffer full, discarding measurement")
		return
	}
	b.buffer[key] = m
}

func (b *BordaReporter) sendPeriodically() {
	log.Debugf("Reporting errors to Borda every %v", b.options.ReportInterval)
	for range time.NewTicker(b.options.ReportInterval).C {
		b.sendBatch()
	}
}

func (b *BordaReporter) sendBatch() {
	b.mx.Lock()
	var copy map[string]*Measurement
	if len(b.buffer) == 0 {
		b.mx.Unlock()
		log.Debug("Nothing to report")
		return
	}
	copy = make(map[string]*Measurement, len(b.buffer))
	for key, m := range b.buffer {
		copy[key] = m
	}
	b.mx.Unlock()

	total := len(copy)

	log.Debugf("Attempting to report %d measurements to Borda", total)
	processed := make([]string, 0, len(copy))
	for key, m := range copy {
		recoverable, err := b.sendMeasurement(m)
		if err != nil {
			if recoverable {
				log.Debugf("Unable to send measurement. Will stop batch and attempt again next time: %v", err)
				break
			} else {
				log.Debugf("Encountered unrecoverable error sending measurement, discarding: %v", err)
			}
		}
		processed = append(processed, key)
	}
	for _, key := range processed {
		delete(copy, key)
	}

	remaining := len(copy)
	sent := total - remaining

	if remaining > 0 {
		log.Debugf("Requeuing %d measurements for later submission", remaining)
		b.mx.Lock()
		for key, m := range copy {
			b.addMeasurement(key, m)
		}
		b.mx.Unlock()
	}

	if sent > 0 {
		log.Debugf("Sent %d measurements", sent)
	} else {
		log.Debug("Failed to send any measurements")
	}
}

func (b *BordaReporter) sendMeasurement(m *Measurement) (bool, error) {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)
	err := json.NewEncoder(buf).Encode(m)
	if err != nil {
		return false, err
	}
	req, decErr := http.NewRequest(http.MethodPost, bordaURL, buf)
	if decErr != nil {
		return false, decErr
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := b.c.Do(req)
	if err != nil {
		return true, err
	}

	switch resp.StatusCode {
	case 201:
		return false, nil
	case 400:
		errorMsg, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return false, fmt.Errorf("Borda replied with 400, but error message couldn't be read: %v", err)
		}
		err = fmt.Errorf("Borda replied with the error: %v", string(errorMsg))
		return false, log.Errorf("%v JSON: %v", err, buf.String())
	default:
		return false, fmt.Errorf("Borda replied with error %d", resp.StatusCode)
	}
}
