package main

import (
	"bytes"
	"io/ioutil"
	"net/http"
	"net/http/httputil"

	"github.com/getlantern/flashlight/client"
)

var (
	// https://github.com/getlantern/lantern/issues/3147
	redirectSites = []string{
		// sites that redirect to http when accessed through https
		"http://www.bbc.co.uk",
		"http://www.speedtest.net",
		// sites that redirect to itself if the "Host:" HTTP header contains port
		"http://lowendbox.com",
		"http://sourceforge.net",
		"http://krypted.com/mac-security/manage-profiles-from-the-command-line-in-os-x-10-9/",
	}

	atsDefaultBody = []byte(`<HTML>
<HEAD>
<TITLE>Not Found on Accelerator</TITLE>
</HEAD>

<BODY BGCOLOR="white" FGCOLOR="black">
<H1>Not Found on Accelerator</H1>
<HR>

<FONT FACE="Helvetica,Arial"><B>
Description: Your request on the specified host was not found.
Check the location and try again.
</B></FONT>
<HR>
</BODY>
`)
)

func verifyFallback(fb *client.ChainedServerInfo, c *http.Client) {
	verifyMimicWhenNoAuthToken(fb, c)
	verifyMimicWithInvalidAuthToken(fb, c)
	for _, s := range redirectSites {
		verifyRedirectSites(fb, c, s)
	}
}

func verifyMimicWhenNoAuthToken(fb *client.ChainedServerInfo, c *http.Client) {
	req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	if err != nil {
		log.Errorf("%v: NewRequest() error : %v", fb.Addr, err)
		return
	}
	// intentionally not set auth token
	doVerifyMimic(fb.Addr, req, c)
}

func verifyMimicWithInvalidAuthToken(fb *client.ChainedServerInfo, c *http.Client) {
	req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	if err != nil {
		log.Errorf("%v: NewRequest() error : %v", fb.Addr, err)
		return
	}
	req.Header.Set("X-LANTERN-AUTH-TOKEN", "invalid")
	doVerifyMimic(fb.Addr, req, c)
}

func doVerifyMimic(addr string, req *http.Request, c *http.Client) {
	resp, err := c.Do(req)
	if err != nil {
		log.Errorf("%v: requesting humans.txt failed: %v", addr, err)
		return
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
	}()
	if resp.StatusCode != 404 {
		log.Errorf("%v: should get 404 if auth failed", addr)
		if *verbose {
			respStr, _ := httputil.DumpResponse(resp, true)
			log.Debug(string(respStr))
		}
		return
	}
	if resp.Header.Get("Content-Type") != "text/html" ||
		resp.Header.Get("Cache-Control") != "no-store" ||
		resp.Header.Get("Connection") != "keep-alive" ||
		resp.Header.Get("Content-Language") != "en" ||
		resp.Header.Get("Content-Length") != "297" {
		log.Errorf("%v: should have correct headers present", addr)
		if *verbose {
			respStr, _ := httputil.DumpResponse(resp, true)
			log.Debug(string(respStr))
		}
		return
	}
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Errorf("%v: error reading response body: %v", addr, err)
		return
	}
	if !bytes.Equal(b, atsDefaultBody) {
		log.Errorf("%v: response body mismatch for invalid request", addr)
		log.Debugf("Body expected: %v", string(atsDefaultBody))
		log.Debugf("Body got: %v", string(b))
		return
	}
	log.Debugf("%v: OK.", addr)
}

func verifyRedirectSites(fb *client.ChainedServerInfo, c *http.Client, url string) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		log.Errorf("error make request to %s: %v", url, err)
		return
	}
	req.Header.Set("X-LANTERN-AUTH-TOKEN", fb.AuthToken)
	resp, err := c.Do(req)
	if err != nil {
		log.Errorf("%v: requesting %s failed: %v", fb.Addr, url, err)
		if *verbose {
			reqStr, _ := httputil.DumpRequestOut(req, true)
			log.Debug(string(reqStr))
		}
		return
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
	}()
	if resp.StatusCode != 200 {
		log.Errorf("%v: bad status code %v for %s", fb.Addr, resp.StatusCode, url)
		if *verbose {
			respStr, _ := httputil.DumpResponse(resp, true)
			log.Debug(string(respStr))
		}
		return
	}
	log.Debugf("%v via %s: OK.", fb.Addr, url)
}
