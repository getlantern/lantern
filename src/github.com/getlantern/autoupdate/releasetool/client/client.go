package client

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
)

// Client provides methods for
type Client struct {
	cfg Config
	cli *http.Client
}

// NewClient allocates a new client with the given configuration.
func NewClient(cfg Config) *Client {
	c := Client{
		cfg: cfg,
		cli: &http.Client{},
	}
	return &c
}

func (c *Client) headers() http.Header {
	h := http.Header{}
	h.Add("Authorization", "Basic "+c.cfg.authHeader())
	h.Add("Content-Type", "application/octect-stream")
	return h
}

// AnnounceRelease relates an asset with a release.
func (c *Client) AnnounceRelease(message *Announcement) (*Announcement, error) {
	var err error
	var uri *url.URL
	var res *http.Response
	var buf []byte

	if uri, err = url.Parse(fmt.Sprintf(endpointReleases, c.cfg.ApplicationID)); err != nil {
		return nil, err
	}

	if buf, err = json.Marshal(message); err != nil {
		return nil, err
	}

	h := c.headers()
	h.Add("Content-Type", "application/json")

	req := &http.Request{
		URL:    uri,
		Method: "POST",
		Header: h,
		Body:   ioutil.NopCloser(bytes.NewBuffer(buf)),
	}

	req.ContentLength = int64(len(buf))

	if res, err = c.cli.Do(req); err != nil {
		return nil, err
	}

	defer res.Body.Close()

	if res.StatusCode == http.StatusCreated {
		// Reading body.
		var msgData []byte
		var msg Announcement

		if msgData, err = ioutil.ReadAll(res.Body); err != nil {
			return nil, err
		}

		if err = json.Unmarshal(msgData, &msg); err != nil {
			return nil, err
		}

		return &msg, nil
	}

	return nil, nil
}

// UploadAsset pushes an asset to equinox.
func (c *Client) UploadAsset(src string) (*AssetResponse, error) {
	var err error
	var fp *os.File
	var buf *bytes.Buffer
	var res *http.Response
	var uri *url.URL

	if uri, err = url.Parse(fmt.Sprintf(endpointAssets, c.cfg.ApplicationID)); err != nil {
		return nil, err
	}

	buf = bytes.NewBuffer(nil)

	// Opening file.
	if fp, err = os.Open(src); err != nil {
		return nil, err
	}

	defer fp.Close()

	io.Copy(buf, fp)

	req := &http.Request{
		URL:    uri,
		Method: "POST",
		Header: c.headers(),
		Body:   ioutil.NopCloser(buf),
	}

	req.ContentLength = int64(buf.Len())

	if res, err = c.cli.Do(req); err != nil {
		return nil, err
	}

	defer res.Body.Close()

	if res.StatusCode == http.StatusCreated {
		// Reading body.
		var msgData []byte
		var msg AssetResponse

		if msgData, err = ioutil.ReadAll(res.Body); err != nil {
			return nil, err
		}

		if err = json.Unmarshal(msgData, &msg); err != nil {
			return nil, err
		}

		return &msg, nil
	}

	return nil, errors.New("Failed to create asset.")
}
