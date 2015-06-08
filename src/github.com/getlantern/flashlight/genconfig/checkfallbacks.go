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
	"os"
	"runtime"
	"strings"
	"sync"

	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/client"
)

var (
	help          = flag.Bool("help", false, "Get usage help")
	fallbacksFile = flag.String("fallbacks", "fallbacks.json", "File containing json array of fallback information")
	verbose       = flag.Bool("verbose", false, "Verbose output for debugging")
	numConns      = flag.Int("connections", 1, "Number of simultaneous connections")

	expectedBody = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"
)

var (
	log = golog.LoggerFor("checkfallbacks")
)

type fallbackServer map[string]interface{}

func main() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	numcores := runtime.NumCPU()

	if *verbose {
		log.Debugf("Using all %d cores on machine", numcores)
	}
	runtime.GOMAXPROCS(numcores)

	fallbacks := make(chan fallbackServer)
	loadFallbacks(fallbacks)
	testFallbacks(fallbacks)
}

// Load the fallback servers list file. Failure to do so will result in
// exiting the program.
func loadFallbacks(fallbacks chan<- fallbackServer) {
	if *fallbacksFile == "" {
		log.Error("Please specify a fallbacks file")
		flag.Usage()
		os.Exit(2)
	}

	fallbacksBytes, err := ioutil.ReadFile(*fallbacksFile)
	if err != nil {
		log.Fatalf("Unable to read fallbacks file at %s: %s", *fallbacksFile, err)
		os.Exit(2)
	}

	var unmarshalledFallbacks []fallbackServer
	err = json.Unmarshal(fallbacksBytes, &unmarshalledFallbacks)
	if err != nil {
		log.Fatalf("Unable to unmarshal json from %v: %v", *fallbacksFile, err)
		os.Exit(1)
	}

	// Channel fallback servers on-demand
	go func() {
		for _, val := range unmarshalledFallbacks {
			fallbacks <- val
		}
		close(fallbacks)
	}()
}

// Test fallback servers. Output to stdout *only* when a test fails.
func testFallbacks(fallbacks <-chan fallbackServer) {
	workersWg := sync.WaitGroup{}

	if *verbose {
		fmt.Printf("Spawning %d workers\n", *numConns)
	}

	workersWg.Add(*numConns)
	for i := 0; i < *numConns; i++ {
		// Worker: consume fallback servers from channel and signal
		// Done() when closed (i.e. range exits)
		go func(i int) {
			for fb := range fallbacks {
				testFallbackServer(fb, i)
			}
			workersWg.Done()
		}(i+1)
	}

	workersWg.Wait()
}

// Perform the test of an individual fallbackServer
func testFallbackServer(fb fallbackServer, workerId int) {
	ip := fb["ip"].(string)
	if fb["pt"] != nil {
		fmt.Printf("Skipping fallback %v because it has pluggable transport enabled", ip)
		return
	}

	cert := fb["cert"].(string)
	// Replace newlines in cert with newline literals
	fb["cert"] = strings.Replace(cert, "\n", "\\n", -1)

	// Test connectivity
	info := &client.ChainedServerInfo{
		Addr:      ip + ":443",
		Cert:      cert,
		AuthToken: fb["auth_token"].(string),
		Pipelined: true,
	}
	dialer, err := info.Dialer()
	if err != nil {
		fmt.Printf("%v: error building dialer: %v", ip, err)
		return
	}
	c := &http.Client{
		Transport: &http.Transport{
			Dial: dialer.Dial,
		},
	}
	req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	resp, err := c.Do(req)
	if err != nil {
		fmt.Printf("%v: requesting humans.txt failed: %v", ip, err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		fmt.Printf("%v: bad status code: %v", ip, resp.StatusCode)
		return
	}
	bytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("%v: error reading response body: %v", ip, err)
		return
	}
	body := string(bytes)
	if body != expectedBody {
		fmt.Printf("%v: wrong body: %s", ip, body)
		return
	}

	if *verbose {
		fmt.Printf("Worker %d: Fallback %v OK.\n", workerId, ip)
	}
}
