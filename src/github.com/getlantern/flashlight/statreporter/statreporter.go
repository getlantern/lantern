package statreporter

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"reflect"
	"sync"
	"time"

	"github.com/getlantern/golog"
)

const (
	statshubUrlTemplate = "https://%s/stats/%s"

	countryDim = "country"
)

var (
	log = golog.LoggerFor("flashlight.statreporter")

	cfgMutex        sync.RWMutex
	currentReporter *reporter
)

type Config struct {
	// ReportingPeriod: how frequently to report
	ReportingPeriod time.Duration

	// StatshubAddr: the address of the statshub server to which to report
	StatshubAddr string
}

type reporter struct {
	cfg          *Config
	poster       reportPoster
	updatesCh    chan *update
	accumulators map[string]*dimGroupAccumulator
}

type dimGroupAccumulator struct {
	dg         *DimGroup
	categories map[string]stats
}

type stats map[string]interface{} // either int64 or string

type report map[string]interface{}

type reportPoster func(report report) error

// Start runs a goroutine that periodically coalesces the collected statistics
// and reports them to statshub via HTTPS post
func Configure(cfg *Config, instanceID string) error {
	if cfg.StatshubAddr == "" {
		return fmt.Errorf("Must specify StatshubAddr if reporting stats")
	}
	return doConfigure(cfg, posterForDimGroupStats(cfg, instanceID), instanceID)
}

func doConfigure(cfg *Config, poster reportPoster, instanceID string) error {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	if currentReporter != nil {
		// Note - the below comparison ignores poster, but in how we use this
		// that's okay.
		if currentReporter.matchesConfig(cfg) {
			log.Debug("Config unchanged")
			return nil
		}

		log.Debug("Stopping old reporter")
		currentReporter.stop()
		currentReporter = nil
	}

	if cfg.ReportingPeriod <= 0 {
		log.Debug("Stat reporting turned off")
		return nil
	}

	if instanceID == "" {
		return fmt.Errorf("Must specify InstanceId if reporting stats")
	}

	log.Debugf("Reporting stats to %s every %s under instance id '%s'", cfg.StatshubAddr, cfg.ReportingPeriod, instanceID)
	currentReporter = &reporter{
		cfg:    cfg,
		poster: poster,

		// We buffer the updates channel to be able to continue accepting
		// updates while we're posting a report
		updatesCh:    make(chan *update, 1000),
		accumulators: make(map[string]*dimGroupAccumulator),
	}

	go currentReporter.run()

	return nil
}

func postUpdate(update *update) {
	cfgMutex.RLock()
	defer cfgMutex.RUnlock()

	if currentReporter != nil {
		select {
		case currentReporter.updatesCh <- update:
			log.Tracef("Posted update: %s", update)
		default:
			log.Tracef("Dropped update: %s", update)
		}
	} else {
		log.Tracef("No reporter, dropping update")
	}
}

func (r *reporter) run() {
	timer := time.NewTimer(r.timeToNextReport())
	go func() {
	ForLoop:
		for {
			select {
			case update, ok := <-r.updatesCh:
				if !ok {
					log.Tracef("updatesCh closed, stop reporting")
					break ForLoop
				}
				log.Tracef("Coalescing update: %s", update)
				// Coalesce
				dgKey := update.dg.String()
				dgAccum := r.accumulators[dgKey]
				if dgAccum == nil {
					dgAccum = &dimGroupAccumulator{
						dg:         update.dg,
						categories: make(map[string]stats),
					}
					r.accumulators[dgKey] = dgAccum
				}
				categoryStats := dgAccum.categories[update.category]
				if categoryStats == nil {
					categoryStats = make(stats)
					dgAccum.categories[update.category] = categoryStats
				}
				switch a := update.action.(type) {
				case set:
					categoryStats[update.key] = int64(a)
				case add:
					existing, found := categoryStats[update.key]
					if !found {
						categoryStats[update.key] = int64(a)
					} else {
						categoryStats[update.key] = existing.(int64) + int64(a)
					}
				case member:
					existing, found := categoryStats[update.key]
					if !found {
						categoryStats[update.key] = map[string]bool{string(a): true}
					} else {
						existing.(map[string]bool)[string(a)] = true
					}
				}
			case <-timer.C:
				r.post()
				timer.Reset(r.timeToNextReport())
			}
		}

		log.Trace("posting one last time before terminating")
		r.post()
	}()
}

func (r *reporter) stop() {
	close(r.updatesCh)
}

func (r *reporter) post() {
	if len(r.accumulators) == 0 {
		log.Debugf("No stats to report")
	} else {
		for _, dgAccum := range r.accumulators {
			err := r.poster(dgAccum.makeReport())
			if err != nil {
				log.Errorf("Unable to post stats for dim %s: %s", dgAccum.dg, err)
			}
		}
		r.accumulators = make(map[string]*dimGroupAccumulator)
	}
}

func (r *reporter) timeToNextReport() time.Duration {
	nextInterval := time.Now().Truncate(r.cfg.ReportingPeriod).Add(r.cfg.ReportingPeriod)
	return nextInterval.Sub(time.Now())
}

func (r *reporter) matchesConfig(cfg *Config) bool {
	return reflect.DeepEqual(cfg, r.cfg)
}

func (dgAccum *dimGroupAccumulator) makeReport() report {
	report := report{
		"dims": dgAccum.dg.dims,
	}

	for category, s := range dgAccum.categories {
		if category == members {
			// Transform maps into arrays
			s2 := make(stats)

			for k, v := range s {
				m := v.(map[string]bool)
				a := make([]string, 0, len(m))
				for member := range m {
					a = append(a, member)
				}
				s2[k] = a
			}
			s = s2
		}
		report[category] = s
	}

	return report
}

func posterForDimGroupStats(cfg *Config, instanceID string) reportPoster {
	return func(report report) error {
		jsonBytes, err := json.Marshal(report)
		if err != nil {
			return fmt.Errorf("Unable to marshal json for stats: %s", err)
		}

		url := fmt.Sprintf(statshubUrlTemplate, cfg.StatshubAddr, instanceID)
		resp, err := http.Post(url, "application/json", bytes.NewReader(jsonBytes))
		if err != nil {
			return fmt.Errorf("Unable to post stats to statshub: %s", err)
		}
		defer func() {
			if err := resp.Body.Close(); err != nil {
				// Log instead of returning, so we can keep the other, more probable, errors
				log.Debugf("Unable to close response body: %s", err)
			}
		}()

		jsonString := string(jsonBytes)
		if resp.StatusCode != 200 {
			return fmt.Errorf("Unexpected response status posting stats %s to statshub: %d", jsonString, resp.StatusCode)
		}

		log.Debugf("Reported %s to statshub", jsonString)
		return nil
	}
}
