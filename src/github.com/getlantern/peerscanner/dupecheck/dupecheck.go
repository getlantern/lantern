package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/peerscanner/cf"
)

func main() {
	allRecs := map[string]map[string][]cloudflare.Record{
		"fallbacks":  make(map[string][]cloudflare.Record),
		"fl-":        make(map[string][]cloudflare.Record),
		"peers":      make(map[string][]cloudflare.Record),
		"roundrobin": make(map[string][]cloudflare.Record),
	}

	u := cf.New("getiantem.org", os.Getenv("CFL_USER"), os.Getenv("CFL_API_KEY"))
	u.Client.Http.Transport = &http.Transport{
		DisableKeepAlives: true,
	}
	recs, err := u.GetAllRecords()
	if err != nil {
		log.Fatalf("Unable to get records: %v", err)
	}

	for _, r := range recs {
		for k, ar := range allRecs {
			if strings.Contains(r.Name, k) {
				fb := ar[r.Value]
				if fb == nil {
					fb = []cloudflare.Record{r}
				} else {
					fb = append(fb, r)
				}
				ar[r.Value] = fb
			}
		}
	}

	for k, ar := range allRecs {
		for ip, recs := range ar {
			if len(recs) > 1 {
				log.Printf("%v appears %d times in %v", ip, len(recs), k)
			}
		}
	}
}
