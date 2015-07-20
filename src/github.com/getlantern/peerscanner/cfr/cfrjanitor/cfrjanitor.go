// Run cfrjanitor as a cron job every few minutes, and it will clean up
// CloudFront distributions created by peerscanner/cfr/cfr_test.go.

package main

import (
	"os"
	"runtime"
	"sync"

	"github.com/getlantern/aws-sdk-go/gen/cloudfront"
	"github.com/getlantern/golog"
	"github.com/getlantern/peerscanner/cfr"
)

const (
	COMMENT = "TEST -- DELETE"
)

var (
	log = golog.LoggerFor("cfrjanitor")
)

func main() {
	numProcs := runtime.NumCPU() * 2
	runtime.GOMAXPROCS(numProcs)
	numWorkers := numProcs * 4
	c := getCfr()
	workCh := make(chan *cfr.Distribution)
	wg := sync.WaitGroup{}
	wg.Add(numWorkers)
	log.Debugf("Spawning %v workers", numWorkers)
	for i := 0; i < numWorkers; i++ {
		go work(c, workCh, &wg)
	}
	dists, err := cfr.ListDistributions(c)
	if err != nil {
		log.Fatalf("Error listing distributions: %v", err)
		return
	}
	for _, dist := range dists {
		workCh <- dist
	}
	// Signal end of work
	for i := 0; i < numWorkers; i++ {
		workCh <- nil
	}
	wg.Wait()
	log.Debug("cfrjanitor done.")
}

func work(c *cloudfront.CloudFront, workCh <-chan *cfr.Distribution, wg *sync.WaitGroup) {
	for dist := range workCh {
		if dist == nil {
			wg.Done()
			return
		} else if dist.Comment != COMMENT {
			continue
		} else if dist.Status == "InProgress" {
			continue
		} else if dist.Enabled {
			// Distributions must be disabled before they can be deleted:
			// http://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/DeleteDistribution.html
			if err := cfr.DisableDistribution(c, dist); err != nil {
				log.Errorf("Error disabling distribution: %v", err)
			} else {
				log.Debugf("Successfully disabled %v", dist)
			}
		} else {
			if err := cfr.DeleteDistribution(c, dist); err != nil {
				log.Errorf("Error deleting distribution %v: %v", dist, err)
			} else {
				log.Debugf("Successfully deleted %v", dist)
			}
		}
	}
}

func getCfr() *cloudfront.CloudFront {
	cfrid := os.Getenv("CFR_ID")
	cfrkey := os.Getenv("CFR_KEY")
	if cfrid == "" || cfrkey == "" {
		log.Fatalf("You need to set CFR_ID and CFR_KEY environment variables (e.g. `source <too-few-secrets>/envvars.bash`)")
	}
	return cfr.New(cfrid, cfrkey, nil)
}
