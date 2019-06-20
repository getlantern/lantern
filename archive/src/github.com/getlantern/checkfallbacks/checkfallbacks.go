// Utility for checking if fallback servers are working properly.
// It outputs failing servers info in STDOUT.  This allows this program to be
// used for automated testing of the fallback servers as a cron job.

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"os"
	"runtime"
	"strings"
	"sync"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/golog"
)

const (
	DeviceID = "999999"
)

var (
	help          = flag.Bool("help", false, "Get usage help")
	verbose       = flag.Bool("verbose", false, "Be verbose (useful for manual testing)")
	fallbacksFile = flag.String("fallbacks", "fallbacks.json", "File containing json array of fallback information")
	numConns      = flag.Int("connections", 1, "Number of simultaneous connections")
	verify        = flag.Bool("verify", false, "Verify the functionality of the fallback")

	expectedBody = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"
)

var (
	log = golog.LoggerFor("checkfallbacks")
)

func main() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	numcores := runtime.NumCPU()
	runtime.GOMAXPROCS(numcores)
	log.Debugf("Using all %d cores on machine", numcores)

	fallbacks := loadFallbacks(*fallbacksFile)
	outputCh := testAllFallbacks(fallbacks)
	for out := range *outputCh {
		if out.err != nil {
			fmt.Printf("[failed fallback check] %v\n", out.err)
		}
		if *verbose && len(out.info) > 0 {
			for _, msg := range out.info {
				fmt.Printf("[output] %v\n", msg)
			}
		}
	}
}

// Load the fallback servers list file. Failure to do so will result in
// exiting the program.
func loadFallbacks(filename string) (fallbacks []client.ChainedServerInfo) {
	if filename == "" {
		log.Error("Please specify a fallbacks file")
		flag.Usage()
		os.Exit(2)
	}

	fileBytes, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatalf("Unable to read fallbacks file at %s: %s", filename, err)
	}

	err = json.Unmarshal(fileBytes, &fallbacks)
	if err != nil {
		log.Fatalf("Unable to unmarshal json from %v: %v", filename, err)
	}

	// Replace newlines in cert with newline literals
	for _, fb := range fallbacks {
		fb.Cert = strings.Replace(fb.Cert, "\n", "\\n", -1)
	}
	return
}

type fullOutput struct {
	err  error
	info []string
}

// Test all fallback servers
func testAllFallbacks(fallbacks []client.ChainedServerInfo) (output *chan fullOutput) {
	outputChan := make(chan fullOutput)
	output = &outputChan

	// Make
	fbChan := make(chan client.ChainedServerInfo)
	// Channel fallback servers on-demand
	go func() {
		for _, val := range fallbacks {
			fbChan <- val
		}
		close(fbChan)
	}()

	// Spawn goroutines and wait for them to finish
	go func() {
		workersWg := sync.WaitGroup{}

		log.Debugf("Spawning %d workers\n", *numConns)

		workersWg.Add(*numConns)
		for i := 0; i < *numConns; i++ {
			// Worker: consume fallback servers from channel and signal
			// Done() when closed (i.e. range exits)
			go func(i int) {
				for fb := range fbChan {
					*output <- testFallbackServer(&fb, i)
				}
				workersWg.Done()
			}(i + 1)
		}
		workersWg.Wait()

		close(outputChan)
	}()

	return
}

// Perform the test of an individual server
func testFallbackServer(fb *client.ChainedServerInfo, workerID int) (output fullOutput) {
	dialer, err := client.ChainedDialer(fb, DeviceID)
	if err != nil {
		output.err = fmt.Errorf("%v: error building dialer: %v", fb.Addr, err)
		return
	}
	c := &http.Client{
		Transport: &http.Transport{
			Dial: dialer.DialFN,
		},
	}
	req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	if err != nil {
		output.err = fmt.Errorf("%v: NewRequest to humans.txt failed: %v", fb.Addr, err)
		return
	}
	if *verbose {
		reqStr, _ := httputil.DumpRequestOut(req, true)
		output.info = []string{"\n" + string(reqStr)}
	}

	req.Header.Set("X-LANTERN-AUTH-TOKEN", fb.AuthToken)
	resp, err := c.Do(req)
	if err != nil {
		output.err = fmt.Errorf("%v: requesting humans.txt failed: %v", fb.Addr, err)
		return
	}
	if *verbose {
		respStr, _ := httputil.DumpResponse(resp, true)
		output.info = append(output.info, "\n"+string(respStr))
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
	}()
	if resp.StatusCode != 200 {
		output.err = fmt.Errorf("%v: bad status code: %v", fb.Addr, resp.StatusCode)
		return
	}
	bytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		output.err = fmt.Errorf("%v: error reading response body: %v", fb.Addr, err)
		return
	}
	body := string(bytes)
	if body != expectedBody {
		output.err = fmt.Errorf("%v: wrong body: %s", fb.Addr, body)
		return
	}

	log.Debugf("Worker %d: Fallback %v OK.\n", workerID, fb.Addr)

	if *verify {
		verifyFallback(fb, c)
	}
	return
}
