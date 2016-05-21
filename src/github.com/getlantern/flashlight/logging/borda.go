package logging

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
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
	// ReportInterval specifies how frequent to report
	ReportInterval time.Duration

	// MaxBufferSize specifies the maximum number of distinct measurements to
	// buffer within the ReportInterval. Anything past this is discarded.
	MaxBufferSize int
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
		Name:   "errors",
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
	} else {
		m.count = 1
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
	if len(b.buffer) == 0 {
		b.mx.Unlock()
		log.Debug("Nothing to report")
		return
	}
	batch := make([]*Measurement, 0, len(b.buffer))
	batchAsMap := make(map[string]*Measurement, len(b.buffer))
	for key, m := range b.buffer {
		if !strings.Contains(string(m.Fields), "error_count") {
			// Append error_count to fields (this is a hack)
			extra := fmt.Sprintf(`, "error_count": %d}`, m.count)
			m.Fields = append(m.Fields[:len(m.Fields)-1], extra...)
		}
		batch = append(batch, m)
		batchAsMap[key] = m
	}
	b.buffer = make(map[string]*Measurement, b.options.MaxBufferSize)
	b.mx.Unlock()

	log.Debugf("Attempting to report %d measurements to Borda", len(batch))
	err := b.doSendBatch(batch)
	if err == nil {
		log.Debugf("Sent %d measurements", len(batch))
		return
	}
	log.Error(err)
	log.Debugf("Rebuffering %d measurements", len(batchAsMap))
	b.mx.Lock()
	for key, m := range batchAsMap {
		b.addMeasurement(key, m)
	}
	b.mx.Unlock()
}

func (b *BordaReporter) doSendBatch(batch []*Measurement) error {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)
	err := json.NewEncoder(buf).Encode(batch)
	if err != nil {
		return log.Errorf("Unable to report measurements: %v", err)
	}

	req, decErr := http.NewRequest(http.MethodPost, bordaURL, buf)
	if decErr != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := b.c.Do(req)
	if err != nil {
		return err
	}

	switch resp.StatusCode {
	case 201:
		return nil
	case 400:
		errorMsg, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return fmt.Errorf("Borda replied with 400, but error message couldn't be read: %v", err)
		}
		err = fmt.Errorf("Borda replied with the error: %v", string(errorMsg))
		return err
	default:
		return fmt.Errorf("Borda replied with error %d", resp.StatusCode)
	}
}
