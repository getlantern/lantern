package reporter

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/measured"
)

var (
	log = golog.LoggerFor("measured.reporter")
)

type influxDBReporter struct {
	httpClient  *http.Client
	url         string
	username    string
	password    string
	defaultTags map[string]string
}

func NewInfluxDBReporter(influxURL, username, password, dbName string, httpClient *http.Client) measured.Reporter {
	if httpClient == nil {
		httpClient = &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
		}
	}
	u := fmt.Sprintf("%s/write?db=%s", strings.TrimRight(influxURL, "/"), dbName)
	log.Debugf("Created InfluxDB reporter: %s", u)
	return &influxDBReporter{httpClient, u, username, password, make(map[string]string)}
}

func (ir *influxDBReporter) ReportError(em map[*measured.Error]int) error {
	data := []*submitData{}
	for k, v := range em {
		data = append(data, &submitData{
			"errors",
			map[string]string{
				"id":    k.ID,
				"error": k.Error,
				"phase": k.Phase,
			},
			map[string]interface{}{
				"count": v,
			},
		})
	}
	log.Tracef("Reporting %d error entry", len(data))
	return ir.submit(data)
}

func (ir *influxDBReporter) ReportLatency(lt []*measured.LatencyTracker) error {
	data := []*submitData{}
	for _, v := range lt {
		data = append(data, &submitData{
			"latency",
			map[string]string{
				"id": v.ID,
			},
			map[string]interface{}{
				"min":       v.Min,
				"max":       v.Max,
				"percent95": v.Percent95,
				"last":      v.Last,
			},
		})
	}
	log.Debugf("Reporting %d latency entry", len(data))
	return ir.submit(data)
}
func (ir *influxDBReporter) ReportTraffic(tt []*measured.TrafficTracker) error {
	data := []*submitData{}
	for _, v := range tt {
		data = append(data, &submitData{
			"traffic",
			map[string]string{
				"id": v.ID,
			},
			map[string]interface{}{
				"min_in":        v.MinIn,
				"max_in":        v.MaxIn,
				"percent95_in":  v.Percent95In,
				"last_in":       v.LastIn,
				"total_in":      v.TotalIn,
				"min_out":       v.MinOut,
				"max_out":       v.MaxOut,
				"percent95_out": v.Percent95Out,
				"last_out":      v.LastOut,
				"total_out":     v.TotalOut,
			},
		})
	}
	log.Debugf("Reporting %d traffic entry", len(data))
	return ir.submit(data)
}

type submitData struct {
	series string
	tags   map[string]string
	fields map[string]interface{}
}

func (ir *influxDBReporter) submit(dl []*submitData) error {
	var buf bytes.Buffer

	// Ref https://influxdb.com/docs/v0.9/write_protocols/write_syntax.html
	for _, d := range dl {
		buf.WriteString(d.series)
		buf.WriteString(",")
		count, i := len(d.tags), 0
		if count == 0 {
			return fmt.Errorf("No tags supplied")
		}
		for k, v := range d.tags {
			i++
			if v == "" {
				return fmt.Errorf("Tag %s is empty", k)
			}
			buf.WriteString(fmt.Sprintf("%s=%s", k, escapeStringField(v)))
			if i < count {
				buf.WriteString(",")
			}
		}
		buf.WriteString(" ")

		count, i = len(d.fields), 0
		if count == 0 {
			return fmt.Errorf("No fields supplied")
		}
		for k, v := range d.fields {
			i++
			switch v.(type) {
			case string:
				s := v.(string)
				if s == "" {
					return fmt.Errorf("Field %s is empty", k)
				}
				buf.WriteString(fmt.Sprintf("%s=%s", k, s))
			case int:
				buf.WriteString(fmt.Sprintf("%s=%di", k, v))
			case float64:
				buf.WriteString(fmt.Sprintf("%s=%f", k, v))
			default:
				panic("Unsupported field type")
			}
			if i < count {
				buf.WriteString(",")
			}
		}

		buf.WriteString(fmt.Sprintf(" %d\n", time.Now().UnixNano()))
	}

	log.Tracef("Write %d bytes to %s", buf.Len(), ir.url)
	req, err := http.NewRequest("POST", ir.url, &buf)
	if err != nil {
		log.Errorf("Error make POST request to %s: %s", ir.url, err)
		return err
	}
	req.SetBasicAuth(ir.username, ir.password)
	rsp, err := ir.httpClient.Do(req)
	if err != nil {
		log.Errorf("Error send POST request to %s: %s", ir.url, err)
		return err
	}
	if rsp.StatusCode != 204 {
		err = fmt.Errorf("Error response from %s: %s", ir.url, rsp.Status)
		log.Error(err)
		return err
	}
	return err
}

func escapeStringField(in string) string {
	var out []byte
	i := 0
	for {
		if i >= len(in) {
			break
		}
		if in[i] == ',' || in[i] == '=' || in[i] == ' ' {
			out = append(out, '\\')
		}
		out = append(out, in[i])
		i += 1

	}
	return string(out)
}
