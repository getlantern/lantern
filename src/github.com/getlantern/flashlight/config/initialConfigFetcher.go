package config

import (
	"io/ioutil"
	"net/http"

	"github.com/getlantern/flashlight/client"
)

func fetchInitialConfig(path string, ps *client.PackagedSettings) error {
	var err error
	for _, s := range ps.ChainedServers {
		dialer, er := s.Dialer()
		if er != nil {
			log.Errorf("Unable to configure chained server. Received error: %v", er)
			continue
		}
		//&http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyUrl)}}
		http := &http.Client{
			Transport: &http.Transport{
				DisableKeepAlives: true,
				Dial:              dialer.Dial,
			},
		}
		err = fetchConfigWithDialer(path, http)
		if err == nil {
			return nil
		}
	}
	return err
}

func fetchConfigWithDialer(path string, http *http.Client) error {

	resp, err := http.Get("https://config.getiantem.org/cloud.yaml.gz")
	if err != nil {
		log.Errorf("Could not fetch initial config? %v", err)
		return err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)

	if err != nil {
		log.Errorf("Could not read message body %v", err)
		return err
	}

	if err := ioutil.WriteFile(path, body, 0644); err != nil {
		log.Errorf("Could not create file at %v, %v", path, err)
		return err
	}
	return nil
}
