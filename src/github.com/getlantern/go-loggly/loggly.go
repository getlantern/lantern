package loggly

import . "github.com/visionmedia/go-debug"
import . "encoding/json"
import "io/ioutil"
import "net/http"
import "strings"
import "bytes"
import "time"
import "sync"
import "fmt"
import "os"
import "io"

const Version = "0.4.3"

const api = "https://logs-01.loggly.com/bulk/{token}"

type Message map[string]interface{}

var debug = Debug("loggly")

var nl = []byte{'\n'}

type Level int

const (
	DEBUG Level = iota
	INFO
	NOTICE
	WARNING
	ERROR
	CRITICAL
	ALERT
	EMERGENCY
)

// Loggly client.
type Client struct {

	// Optionally output logs to the given writer.
	Writer io.Writer

	// Log level defaulting to INFO.
	Level Level

	// Size of buffer before flushing [100]
	BufferSize int

	// Flush interval regardless of size [5s]
	FlushInterval time.Duration

	// Loggly end-point.
	Endpoint string

	// Token string.
	Token string

	// Underlying HTTP client, if empty a new HTTP client will be created.
	httpClient *http.Client

	// Default properties.
	Defaults Message
	buffer   [][]byte
	tags     []string
	sync.Mutex
	httpClientMu sync.RWMutex
}

// New returns a new loggly client with the given `token`.
// Optionally pass `tags` or set them later with `.Tag()`.
func New(token string, tags ...string) *Client {
	host, err := os.Hostname()
	defaults := Message{}

	if err == nil {
		defaults["hostname"] = host
	}

	c := &Client{
		Level:         INFO,
		BufferSize:    100,
		FlushInterval: 5 * time.Second,
		Token:         token,
		Endpoint:      strings.Replace(api, "{token}", token, 1),
		buffer:        make([][]byte, 0),
		Defaults:      defaults,
	}

	c.Tag(tags...)

	go c.start()

	return c
}

// Send buffers `msg` for async sending.
func (c *Client) Send(msg Message) error {
	if _, exists := msg["timestamp"]; !exists {
		msg["timestamp"] = time.Now().UnixNano() / int64(time.Millisecond)
	}
	merge(msg, c.Defaults)

	json, err := Marshal(msg)
	if err != nil {
		return err
	}

	c.Lock()
	defer c.Unlock()

	if c.Writer != nil {
		fmt.Fprintf(c.Writer, "%s\n", string(json))
	}

	c.buffer = append(c.buffer, json)

	debug("buffer (%d/%d) %v", len(c.buffer), c.BufferSize, msg)

	if len(c.buffer) >= c.BufferSize {
		go func() {
			if err := c.Flush(); err != nil {
				debug("Unable to flush: %v", err)
			}
		}()
	}

	return nil
}

// Write raw data to loggly.
func (c *Client) Write(b []byte) (int, error) {
	c.Lock()
	defer c.Unlock()

	if c.Writer != nil {
		fmt.Fprintf(c.Writer, "%s", b)
	}

	c.buffer = append(c.buffer, b)

	debug("buffer (%d/%d) %q", len(c.buffer), c.BufferSize, b)

	if len(c.buffer) >= c.BufferSize {
		go func() {
			if err := c.Flush(); err != nil {
				debug("Unable to flush: %v", err)
			}
		}()
	}

	return len(b), nil
}

// Debug log.
func (c *Client) Debug(t string, props ...Message) error {
	if c.Level > DEBUG {
		return nil
	}
	msg := Message{"level": "debug", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Info log.
func (c *Client) Info(t string, props ...Message) error {
	if c.Level > INFO {
		return nil
	}
	msg := Message{"level": "info", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Notice log.
func (c *Client) Notice(t string, props ...Message) error {
	if c.Level > NOTICE {
		return nil
	}
	msg := Message{"level": "notice", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Warning log.
func (c *Client) Warn(t string, props ...Message) error {
	if c.Level > WARNING {
		return nil
	}
	msg := Message{"level": "warning", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Error log.
func (c *Client) Error(t string, props ...Message) error {
	if c.Level > ERROR {
		return nil
	}
	msg := Message{"level": "error", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Critical log.
func (c *Client) Critical(t string, props ...Message) error {
	if c.Level > CRITICAL {
		return nil
	}
	msg := Message{"level": "critical", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Alert log.
func (c *Client) Alert(t string, props ...Message) error {
	if c.Level > ALERT {
		return nil
	}
	msg := Message{"level": "alert", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// Emergency log.
func (c *Client) Emergency(t string, props ...Message) error {
	if c.Level > EMERGENCY {
		return nil
	}
	msg := Message{"level": "emergency", "type": t}
	merge(msg, props...)
	return c.Send(msg)
}

// SetHTTPClient sets the HTTP client the loggly client is going to use to
// connect to the loggly API.
func (c *Client) SetHTTPClient(newClient *http.Client) {
	c.httpClientMu.Lock()
	c.httpClient = newClient
	c.httpClientMu.Unlock()
}

// Flush the buffered messages.
func (c *Client) Flush() error {
	c.httpClientMu.RLock()
	defer c.httpClientMu.RUnlock()

	// Using or creating HTTP client.
	var httpClient *http.Client
	if c.httpClient == nil {
		httpClient = &http.Client{}
	} else {
		httpClient = c.httpClient
	}

	c.Lock()

	if len(c.buffer) == 0 {
		debug("no messages to flush")
		c.Unlock()
		return nil
	}

	debug("flushing %d messages", len(c.buffer))
	body := bytes.Join(c.buffer, nl)

	c.buffer = nil
	c.Unlock()

	debug("POST %s with %d bytes", c.Endpoint, len(body))
	req, err := http.NewRequest("POST", c.Endpoint, bytes.NewBuffer(body))
	if err != nil {
		debug("error: %v", err)
		return err
	}

	req.Header.Add("User-Agent", "go-loggly (version: "+Version+")")
	req.Header.Add("Content-Type", "text/plain")
	req.Header.Add("Content-Length", string(len(body)))

	tags := c.tagsList()
	if tags != "" {
		req.Header.Add("X-Loggly-Tag", tags)
	}

	res, err := httpClient.Do(req)
	if err != nil {
		debug("error: %v", err)
		return err
	}

	defer func() {
		if err := res.Body.Close(); err != nil {
			debug("Unable to close response body: %v", err)
		}
	}()

	debug("%d response", res.StatusCode)
	if res.StatusCode >= 400 {
		resp, _ := ioutil.ReadAll(res.Body)
		debug("error: %s", string(resp))
	}

	return err
}

// Tag adds the given `tags` for all logs.
func (c *Client) Tag(tags ...string) {
	c.Lock()
	defer c.Unlock()

	for _, tag := range tags {
		c.tags = append(c.tags, tag)
	}
}

// Return a comma-delimited tag list string.
func (c *Client) tagsList() string {
	c.Lock()
	defer c.Unlock()

	return strings.Join(c.tags, ",")
}

// Start flusher.
func (c *Client) start() {
	for {
		time.Sleep(c.FlushInterval)
		debug("interval %v reached", c.FlushInterval)
		if err := c.Flush(); err != nil {
			debug("Unable to flush: %v", err)
		}
	}
}

// Merge others into a.
func merge(a Message, others ...Message) {
	for _, msg := range others {
		for k, v := range msg {
			a[k] = v
		}
	}
}
