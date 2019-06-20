package client

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"
	"time"

	"github.com/getlantern/errors"
	"github.com/getlantern/golog"
	"github.com/oxtoacart/bpool"
)

var (
	log = golog.LoggerFor("borda")

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

	// Values contains numeric values of the measurement. These will be stored as
	// "fields" in InfluxDB.
	//
	// Example: { "num_errors": 67 }
	Values map[string]float64 `json:"values,omitempty"`

	// Dimensions captures key/value pairs which characterize the measurement.
	// Dimensions are stored as "tags" or "fields" in InfluxDB depending on which
	// dimensions have been configured as "IndexedDimensions" on the Collector.
	//
	// Example: { "requestid": "18af517b-004f-486c-9978-6cf60be7f1e9",
	//            "ipv6": "2001:0db8:0a0b:12f0:0000:0000:0000:0001",
	//            "host": "myhost.mydomain.com",
	//            "total_cpus": "2",
	//            "cpu_idle": 10.1,
	//            "cpu_system": 53.3,
	//            "cpu_user": 36.6,
	//            "connected_to_internet": true }
	Dimensions json.RawMessage `json:"dimensions,omitempty"`
}

// Options provides configuration options for borda clients
type Options struct {
	// BatchInterval specifies how frequent to report to borda
	BatchInterval time.Duration

	// Client used to report to Borda
	Client *http.Client
}

// Reducer is a function that merges the newValues into the existingValues for
// a given measurement.
type Reducer func(existingValues map[string]float64, newValues map[string]float64)

// Submitter is a functon that submits measurements to borda. If the measurement
// was successfully queued for submission, this returns nil.
type Submitter func(values map[string]float64, dimensions map[string]interface{}) error

type submitter func(key string, ts time.Time, values map[string]float64, jsonDimensions []byte) error

// Client is a client that submits measurements to the borda server.
type Client struct {
	c            *http.Client
	options      *Options
	buffers      map[int]map[string]*Measurement
	submitters   map[int]submitter
	nextBufferID int
	mx           sync.Mutex
}

// NewClient creates a new borda client.
func NewClient(opts *Options) *Client {
	if opts == nil {
		opts = &Options{}
	}
	if opts.BatchInterval <= 0 {
		log.Debugf("BatchInterval has to be greater than zero, defaulting to 5 minutes")
		opts.BatchInterval = 5 * time.Minute
	}
	if opts.Client == nil {
		opts.Client = &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					ClientSessionCache: tls.NewLRUClientSessionCache(100),
				},
			},
		}
	}

	b := &Client{
		c:          opts.Client,
		options:    opts,
		buffers:    make(map[int]map[string]*Measurement),
		submitters: make(map[int]submitter),
	}

	go b.sendPeriodically()
	return b
}

// ReducingSubmitter returns a Submitter whose measurements are reduced using
// the specified Reducer. name specifies the name of the measurements and
// maxBufferSize specifies the maximum number of distinct measurements to buffer
// within the BatchInterval. Anything past this is discarded.
func (c *Client) ReducingSubmitter(name string, maxBufferSize int, reduce Reducer) Submitter {
	if maxBufferSize <= 0 {
		log.Debugf("maxBufferSize has to be greater than zero, defaulting to 1000")
		maxBufferSize = 1000
	}
	c.mx.Lock()
	defer c.mx.Unlock()
	bufferID := c.nextBufferID
	c.nextBufferID++
	submitter := func(key string, ts time.Time, values map[string]float64, jsonDimensions []byte) error {
		buffer := c.buffers[bufferID]
		if buffer == nil {
			// Lazily initialize buffer
			buffer = make(map[string]*Measurement)
			c.buffers[bufferID] = buffer
		}
		existing, found := buffer[key]
		if found {
			reduce(existing.Values, values)
			if ts.After(existing.Ts) {
				existing.Ts = ts
			}
		} else if len(buffer) == maxBufferSize {
			return errors.New("Exceeded max buffer size, discarding measurement")
		} else {
			buffer[key] = &Measurement{
				Name:       name,
				Ts:         ts,
				Values:     values,
				Dimensions: jsonDimensions,
			}
		}
		return nil
	}
	c.submitters[bufferID] = submitter

	return func(values map[string]float64, dimensions map[string]interface{}) error {
		jsonDimensions, encodeErr := json.Marshal(dimensions)
		if encodeErr != nil {
			return errors.New("Unable to marshal dimensions: %v", encodeErr)
		}
		key := string(jsonDimensions)
		c.mx.Lock()
		err := submitter(key, time.Now(), values, jsonDimensions)
		c.mx.Unlock()
		return err
	}
}

func (c *Client) sendPeriodically() {
	log.Debugf("Reporting to Borda every %v", c.options.BatchInterval)
	for range time.NewTicker(c.options.BatchInterval).C {
		c.Flush()
	}
}

// Flush flushes any currently buffered data.
func (c *Client) Flush() {
	c.mx.Lock()
	currentBuffers := c.buffers
	// Clear out buffers
	c.buffers = make(map[int]map[string]*Measurement, len(c.buffers))
	c.mx.Unlock()

	// Count measurements
	numMeasurements := 0
	for _, buffer := range currentBuffers {
		numMeasurements += len(buffer)
	}
	if numMeasurements == 0 {
		log.Debug("Nothing to report")
		return
	}

	// Make batch
	batch := make([]*Measurement, 0, numMeasurements)
	for _, buffer := range currentBuffers {
		for _, m := range buffer {
			batch = append(batch, m)
		}
	}

	log.Debugf("Attempting to report %d measurements to Borda", len(batch))
	err := c.doSendBatch(batch)
	if err == nil {
		log.Debugf("Sent %d measurements", len(batch))
		return
	}
	log.Error(err)
	log.Debugf("Rebuffering %d measurements", numMeasurements)
	c.mx.Lock()
	for bufferID, buffer := range currentBuffers {
		submitter := c.submitters[bufferID]
		for key, m := range buffer {
			submitter(key, m.Ts, m.Values, m.Dimensions)
		}
	}
	c.mx.Unlock()
}

func (c *Client) doSendBatch(batch []*Measurement) error {
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

	resp, err := c.c.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

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
