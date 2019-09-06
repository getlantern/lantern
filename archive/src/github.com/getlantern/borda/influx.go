package borda

import (
	"fmt"
	"github.com/influxdata/influxdb/client/v2"
)

// InfluxWriter creates a WriteFunc that writes to InfluxDB
func InfluxWriter(
	influxURL string, // identifies the url to the InfluxDB server
	user string, // the InfluxDB username
	pass string, // the InfluxDB password
) (WriteFunc, error) {
	var err error
	influx, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     influxURL,
		Username: user,
		Password: pass,
	})
	if err != nil {
		return nil, fmt.Errorf("Unable to create InfluxDB client: %v", err)
	}
	return influx.Write, nil
}
