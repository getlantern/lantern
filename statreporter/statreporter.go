package statreporter

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	"github.com/getlantern/flashlight/log"
)

const (
	StatshubUrlTemplate = "https://%s/stats/%s"
)

const (
	increments = "increments"
	gauges     = "gauges"
)

const (
	set = iota
	add = iota
)

type update struct {
	category string
	action   int
	key      string
	val      int64
}

type UpdateBuilder struct {
	category string
	key      string
}

var (
	period       time.Duration
	addr         string
	id           string
	country      string
	updatesCh    chan *update
	accumulators map[string]map[string]int64
	started      int32
)

// Start runs a goroutine that periodically coalesces the collected statistics
// and reports them to statshub via HTTP post
func Start(reportingPeriod time.Duration, statshubAddr string, instanceId string, countryCode string) {
	alreadyStarted := !atomic.CompareAndSwapInt32(&started, 0, 1)
	if alreadyStarted {
		log.Debugf("statreporter already started, not starting again")
		return
	}
	period = reportingPeriod
	addr = statshubAddr
	id = instanceId
	country = strings.ToLower(countryCode)
	// We buffer the updates channel to be able to continue accepting updates while we're posting a report
	updatesCh = make(chan *update, 10000)
	accumulators = make(map[string]map[string]int64)

	timer := time.NewTimer(timeToNextReport())
	for {
		select {
		case update := <-updatesCh:
			// Coalesce
			accum := accumulators[update.category]
			if accum == nil {
				accum = make(map[string]int64)
				accumulators[update.category] = accum
			}
			switch update.action {
			case set:
				accum[update.key] = update.val
			case add:
				accum[update.key] = accum[update.key] + update.val
			}
		case <-timer.C:
			if len(accumulators) == 0 {
				log.Debugf("No stats to report")
			} else {
				err := postStats(accumulators)
				if err != nil {
					log.Errorf("Error on posting stats: %s", err)
				}
				accumulators = make(map[string]map[string]int64)
			}
			timer.Reset(timeToNextReport())
		}
	}
}

// OnBytesGiven registers the fact that bytes were given (sent or received)
func OnBytesGiven(clientIp string, bytes int64) {
	Increment("bytesGiven").Add(bytes)
	Increment("bytesGivenByFlashlight").Add(bytes)
}

func Increment(key string) *UpdateBuilder {
	return &UpdateBuilder{
		increments,
		key,
	}
}

func Gauge(key string) *UpdateBuilder {
	return &UpdateBuilder{
		gauges,
		key,
	}
}

func (b *UpdateBuilder) Add(val int64) {
	postUpdate(&update{
		b.category,
		add,
		b.key,
		val,
	})
}

func (b *UpdateBuilder) Set(val int64) {
	postUpdate(&update{
		b.category,
		set,
		b.key,
		val,
	})
}

func postUpdate(update *update) {
	if isStarted() {
		select {
			case updatesCh <- update:
				// update posted
			default:
				// drop stat to avoid blocking
			}
	}
}

func isStarted() bool {
	return atomic.LoadInt32(&started) == 1
}

func timeToNextReport() time.Duration {
	nextInterval := time.Now().Truncate(period).Add(period)
	return nextInterval.Sub(time.Now())
}

func postStats(accumulators map[string]map[string]int64) error {
	report := map[string]interface{}{
		"dims": map[string]string{
			"country": country,
		},
	}

	for category, accum := range accumulators {
		report[category] = accum
	}

	jsonBytes, err := json.Marshal(report)
	if err != nil {
		return fmt.Errorf("Unable to marshal json for stats: %s", err)
	}

	url := fmt.Sprintf(StatshubUrlTemplate, addr, id)
	resp, err := http.Post(url, "application/json", bytes.NewReader(jsonBytes))
	if err != nil {
		return fmt.Errorf("Unable to post stats to statshub: %s", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("Unexpected response status posting stats to statshub: %d", resp.StatusCode)
	}

	log.Debugf("Reported %s to statshub", string(jsonBytes))
	return nil
}
