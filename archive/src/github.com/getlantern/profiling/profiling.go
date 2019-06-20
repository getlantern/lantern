// package profiling provides support for easily doing CPU and memory profiling
// from within Go programs.
package profiling

import (
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime/pprof"
	"time"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("profiling")
)

// Start starts profiling, saving cpu and memory profiles to the specified cpu
// and mem filenames.  To disable cpu/mem profiling, specify blank strings for
// the cpu and/or mem filenames.
//
// Note - timestamps will be automatically added to the filenames to ensure
// uniqueness. For example "mem.prof" becomes
// "mem_20150119_080853.639750789.prof".
//
// Start returns a function that finishes profiling. It can be useful to call in
// a defer in your main method, for example.
//
// Start also installs a handler for SIGINT that saves profiling information if
// the process receives a SIGINT.
func Start(cpu string, mem string) func() {
	if cpu != "" {
		startCPUProfiling(cpu)
	}

	if cpu != "" || mem != "" {
		saveProfilingOnSigINT(cpu, mem)
	}

	return func() {
		if cpu != "" {
			stopCPUProfiling(cpu)
		}
		if mem != "" {
			saveMemProfile(mem)
		}
	}
}

func startCPUProfiling(filename string) {
	filename = withTimestamp(filename)
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	if err := pprof.StartCPUProfile(f); err != nil {
		log.Fatalf("Unable to start profiling: %v", err)
	}
	log.Debugf("Process will save cpu profile to %s after terminating", filename)
}

func stopCPUProfiling(filename string) {
	log.Debugf("Saving CPU profile to: %s", filename)
	pprof.StopCPUProfile()
}

func saveMemProfile(filename string) {
	filename = withTimestamp(filename)
	f, err := os.Create(filename)
	if err != nil {
		log.Errorf("Unable to create file to save memprofile: %s", err)
		return
	}
	log.Debugf("Saving heap profile to: %s", filename)
	if err := pprof.WriteHeapProfile(f); err != nil {
		log.Debugf("Unable to write heap profile: %v", err)
	}
	if err := f.Close(); err != nil {
		log.Debugf("Unable to close file: %v", err)
	}
}

func saveProfilingOnSigINT(cpu string, mem string) {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		if cpu != "" {
			stopCPUProfiling(cpu)
		}
		if mem != "" {
			saveMemProfile(mem)
		}
		os.Exit(100)
	}()
}

func withTimestamp(filename string) string {
	file := filename
	ext := filepath.Ext(file)
	if ext != "" {
		file = file[:len(file)-len(ext)]
	}
	file = fmt.Sprintf("%s_%s", file, time.Now().Format("20060102_150405.000000000"))
	if ext != "" {
		file = file + ext
	}
	return file
}
