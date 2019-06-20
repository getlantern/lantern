package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/getlantern/borda"
	"github.com/getlantern/tlsdefaults"
	"github.com/golang/glog"
	"github.com/vharitonsky/iniflags"
)

var (
	httpsaddr     = flag.String("httpsaddr", ":62443", "The address at which to listen for HTTPS connections")
	pkfile        = flag.String("pkfile", "pk.pem", "Path to the private key PEM file")
	certfile      = flag.String("certfile", "cert.pem", "Path to the certificate PEM file")
	indexeddims   = flag.String("indexeddims", "app,client_ip,proxy_host", "Indexed Dimensions")
	influxurl     = flag.String("influxurl", "http://localhost:8086", "InfluxDB URL")
	influxdb      = flag.String("influxdb", "lantern2", "InfluxDB database name")
	influxuser    = flag.String("influxuser", "lantern2", "InfluxDB username")
	influxpass    = flag.String("influxpass", "", "InfluxDB password")
	batchsize     = flag.Int("batchsize", 1000, "Batch size")
	batchwindow   = flag.Duration("batchwindow", 30*time.Second, "Batch window")
	maxretries    = flag.Int("maxretries", 100, "Maximum retries to write to InfluxDB before giving up")
	retryinterval = flag.Duration("retryinterval", 30*time.Second, "How long to wait between retries")
)

func main() {
	iniflags.Parse()

	if *influxpass == "" {
		glog.Error("Please specify an influxpass")
		flag.Usage()
		os.Exit(1)
	}

	hl, err := tlsdefaults.Listen(*httpsaddr, *pkfile, *certfile)
	if err != nil {
		glog.Fatalf("Unable to listen HTTPS: %v", err)
	}
	fmt.Fprintf(os.Stdout, "Listening for HTTPS connections at %v\n", hl.Addr())

	write, err := borda.InfluxWriter(*influxurl, *influxuser, *influxpass)
	if err != nil {
		glog.Fatalf("Unable to initialize InfluxDB writer: %v", err)
	}

	c := borda.NewCollector(&borda.Options{
		IndexedDimensions: strings.Split(*indexeddims, ","),
		WriteToDatabase:   write,
		DBName:            *influxdb,
		BatchSize:         *batchsize,
		MaxBatchWindow:    *batchwindow,
		MaxRetries:        *maxretries,
		RetryInterval:     *retryinterval,
	})

	go func() {
		err := http.Serve(hl, c)
		if err != nil {
			glog.Fatalf("Error serving HTTPS: %v", err)
		}
	}()

	err = c.Wait(-1)
	if err != nil {
		glog.Fatalf("Error running borda: %v", err)
	}
}
