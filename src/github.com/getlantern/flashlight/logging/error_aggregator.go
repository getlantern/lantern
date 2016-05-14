package logging

import (
	"sync"
	"time"
)

//
// TODO: import this instead of copying the Error code here (pending PR merge)
//

// Error wraps system and application defined errors in unified structure for
// reporting and logging. It's not meant to be created directly. User New(),
// Wrap() and Report() instead.
type Error struct {
	// Source captures the underlying error that's wrapped by this Error
	Source error `json:"-"`
	// Stack is caller's stack when Error is created
	//Stack stack.CallStack `json:"-"`
	// TS is the timestamp when Error is created
	TS time.Time `json:"timestamp"`
	// Package is the package of the code when Error is created
	Package string `json:"package"` // lantern
	// Func is the function name when Error is created
	Func string `json:"func"` // foo.Bar
	// FileLine is the file path relative to GOPATH together with the line when
	// Error is created.
	FileLine string `json:"file_line"` // github.com/lantern/foo.go:10
	// Go type name or constant/variable name of the error
	GoType string `json:"type"`
	// Error description, by either Go library or application

	Desc string `json:"desc"`
	// The operation which triggers the error to happen
	Op string `json:"operation,omitempty"`
	// Any extra fields
	Extra map[string]string `json:"extra,omitempty"`

	// ReportFileLine is the file and line where the error is reported
	ReportFileLine string `json:"report_file_line"`
	// ReportTS is the timestamp when Error is reported
	ReportTS time.Time `json:"report_timestamp"`
	// ReportStack is caller's stack when Error is reported
	//ReportStack stack.CallStack `json:"-"`

	//*ProxyingInfo
	//*UserLocale
	//*HTTPRequest
	//*HTTPResponse
	//*SystemInfo
}

type AggregatedError struct {
	// TimeStamp of the first received error of the group
	FirstTimeStamp time.Time `json:"first_timestamp"`

	// TimeStamp of the last received error of the group
	LastTimeStamp time.Time `json:"last_timestamp"`

	// Package is the package of the code when Error is created
	Package string `json:"package"` // lantern

	// Func is the function name when Error is created
	Func string `json:"func"` // foo.Bar

	// FileLine is the file path relative to GOPATH together with the line when
	// Error is created.
	FileLine string `json:"file_line"` // github.com/lantern/foo.go:10

	// Go type name or constant/variable name of the error
	GoType string `json:"type"`

	// Error description, by either Go library or application
	Desc string `json:"desc"`

	// The operation which triggers the error to happen
	Op string `json:"operation,omitempty"`

	// Number of instances of this error per reporting period
	Count int `json:count`

	// Any extra fields
	Extra map[string]string `json:"extra,omitempty"`
}

type Aggregator struct {
	aggErrs map[string]*AggregatedError
	errMtx  sync.Mutex
	t       *time.Ticker

	borda *BordaReporter
}

type AggregatorOptions struct {
	Interval time.Duration
}

func NewAggregator(opts *AggregatorOptions) *Aggregator {
	if opts.Interval >= 0 {
		opts.Interval = time.Minute
	}

	a := &Aggregator{
		aggErrs: make(map[string]*AggregatedError),
		t:       time.NewTicker(opts.Interval),
		borda: NewBordaReporter(&BordaReporterOptions{
			MaxChunkSize: 10,
		}),
	}

	go func() {
		for range a.t.C {
			a.errMtx.Lock()
			frozenMap := a.aggErrs
			a.aggErrs = make(map[string]*AggregatedError)
			a.errMtx.Unlock()

			// This will block when calling AddMeasurement, so we operate on
			// the map that has been take out of aggregation, where we start over
			for _, e := range frozenMap {
				fields := map[string]interface{}{
					"first_timestamp": e.FirstTimeStamp,
					"last_timestamp":  e.LastTimeStamp,
					"package":         e.Package,
					"func":            e.Func,
					"file_line":       e.FileLine,
					"type":            e.GoType,
					"desc":            e.Desc,
					"count":           e.Count,
				}

				// Optional fields
				if e.Op != "" {
					fields["operation"] = e.Op
				}
				if e.Extra != nil {
					fields["extra"] = e.Extra
				}

				m := &Measurement{
					Name:   "client_measurement",
					Ts:     time.Now(),
					Fields: fields,
				}
				if _, err := a.borda.AddMeasurement(m); err != nil {
					log.Errorf("Error reporting measurements to Borda: %v", err)
				}
			}
		}
	}()

	return a
}

func (a *Aggregator) AggregateError(e *Error) {
	a.errMtx.Lock()
	defer a.errMtx.Unlock()

	if v, ok := a.aggErrs[e.FileLine]; ok {
		v.LastTimeStamp = time.Now()
		v.Count++
		a.aggErrs[e.FileLine] = v
	} else {
		a.aggErrs[e.FileLine] = &AggregatedError{
			FirstTimeStamp: time.Now(),
			LastTimeStamp:  time.Now(),
			Package:        e.Package,
			Func:           e.Func,
			FileLine:       e.FileLine,
			GoType:         e.GoType,
			Desc:           e.Desc,
			Op:             e.Op,
			Extra:          e.Extra,
		}
	}
}
