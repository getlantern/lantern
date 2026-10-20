package main

import (
	"context"
	"encoding/json"
	"flag"
	"io"
	"log"
	"log/slog"
	"os"
	"time"
)

func main() {
	log.SetOutput(io.Discard)
	slog.SetDefault(slog.New(slog.NewTextHandler(io.Discard, nil)))
	os.Exit(command(os.Args[1:], os.Stdout))
}

func command(args []string, output io.Writer) int {
	result := Result{SchemaVersion: 1, Phase: "input", Code: "invalid_arguments"}
	write := func() int {
		if json.NewEncoder(output).Encode(result) != nil || !result.OK {
			return 1
		}
		return 0
	}
	flags := flag.NewFlagSet("migration-probe", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	expectedPath := flags.String("expected", "", "")
	mode := flags.String("mode", "verify", "")
	timeout := flags.Duration("timeout", 90*time.Second, "")
	probeURL := flags.String("probe-url", "", "")
	if flags.Parse(args) != nil || flags.NArg() != 0 || *expectedPath == "" ||
		(*mode != "verify" && *mode != "connect" && *mode != "disconnect") ||
		*timeout <= 0 || *timeout > 15*time.Minute ||
		(*mode == "connect" && !validProbeURL(*probeURL)) || (*mode != "connect" && *probeURL != "") {
		return write()
	}
	result.Phase = *mode
	expected, err := readExpected(*expectedPath)
	if err != nil {
		result.Code = "invalid_expected_fixture"
		return write()
	}
	client, err := newPlatformClient()
	if err != nil {
		result.Code = "unsupported_platform"
		return write()
	}
	defer client.Close()
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()
	result = runProbe(ctx, *mode, *probeURL, expected, client, httpsProbe)
	return write()
}
