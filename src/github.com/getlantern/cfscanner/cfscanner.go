package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
)

var (
	help       = flag.Bool("help", false, "Get usage help")
	numWorkers = flag.Int("workers", 1, "Number of concurrent workers")
)

func webSlurp(url string) (string, error) {
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("Error fetching IP list: %v", err)
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("Error trying to read response: %v", err)
	}
	return string(body), nil
}

type masquerade struct {
	Domain    string
	IpAddress string
	RootCA    *castat
}

type castat struct {
	CommonName string
	Cert       string
	freq       float64
}

func main() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	s, err := webSlurp("https://www.cloudflare.com/ips-v4")
	if err != nil {
		log.Fatal(err)
	}
	ipch := make(chan string)
	ipwg := sync.WaitGroup{}
	lines := strings.Split(s, "\n")
	ipwg.Add(len(lines))
	for _, line := range lines {
		go enumerateRange(line, ipch, &ipwg)
	}

	// Send death pill to all workers when we're done feeding IPs.
	go func() {
		ipwg.Wait()
		for i := 0; i < *numWorkers; i++ {
			ipch <- ""
		}
	}()

	reswg := sync.WaitGroup{}
	reswg.Add(*numWorkers)
	resch := make(chan *masquerade)
	go func() {
		reswg.Wait()
		resch <- nil
	}()
	for i := 0; i < *numWorkers; i++ {
		go checkIPs(ipch, resch, &reswg)
	}
	for m := range resch {
		if m == nil {
			break
		}
		fmt.Println("Now I would merge CAs and save", m)
	}
}

func checkIPs(ipch <-chan string, resch chan<- *masquerade, wg *sync.WaitGroup) {
	defer wg.Done()
	for ip := range ipch {
		if ip == "" {
			break
		}
		m := checkIP(ip)
		if m != nil {
			resch <- m
		}
	}
}

func checkIP(ip string) *masquerade {
	fmt.Println("Now I would check whether the IP can be fronted to, and get a domain and CA for it.")
	return &masquerade{}
}

func enumerateRange(cidr string, ch chan<- string, wg *sync.WaitGroup) {
	defer wg.Done()
	ip, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		log.Fatal(err)
	}
	for ip := ip.Mask(ipnet.Mask); ipnet.Contains(ip); inc(ip) {
		if ip.IsGlobalUnicast() {
			ch <- ip.String()
		}
	}
}

func inc(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}
