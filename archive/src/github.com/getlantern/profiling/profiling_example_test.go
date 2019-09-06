package profiling

import "github.com/getlantern/profiling"

func ExampleStart() {
	finishProfiling := profiling.Start("cpu.prof", "mem.prof")
	defer finishProfiling()
}
