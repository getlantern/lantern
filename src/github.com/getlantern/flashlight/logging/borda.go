package logging

import (
	"net/http"
	"time"
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
	Fields map[string]interface{} `json:"fields,omitempty"`
}

type BordaReporterOptions struct {
	MaxChunkSize int
}

type BordaReporter struct {
	c       *http.Client
	options *BordaReporterOptions

	mBuf  []*Measurement
	nMeas int
}

func NewBordaReporter(opts *BordaReporterOptions) *BordaReporter {
	if opts.MaxChunkSize <= 0 {
		log.Debugf("BordaClient MaxChunkSize option can't be less than 1. Setting default value of 10.")
		opts.MaxChunkSize = 10
	}

	return &BordaReporter{
		c:       &http.Client{},
		options: opts,
		mBuf:    make([]*Measurement, opts.MaxChunkSize),
	}
}

func (b *BordaReporter) AddMeasurement(m *Measurement) error {
	b.mBuf[b.nMeas] = m
	b.nMeas = b.nMeas + 1

	if b.nMeas > b.options.MaxChunkSize {
		b.sendChunk()
		b.nMeas = 0
	}
	return nil
}

func (b *BordaReporter) sendChunk() error {
	for i := 0; i < b.nMeas; i++ {
		if err := sendMeasurement(b.mBuf[i]); err != nil {
			// TODO, what to do?
		}
	}
	return nil
}

func sendMeasurement(m *Measurement) error {
	// TODO
	return nil
}
