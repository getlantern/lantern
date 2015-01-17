// main simply contains the primary web serving code that allows peers to 
// register and unregister as give mode peers running within the Lantern
// network
package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	//"io/ioutil"
	"strings"
	"time"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/peerscanner/common"
)

type Reg struct {
	Name string
	Ip   string
	Port int
}

var cf = common.NewCloudFlareUtil()

func main() {
	if cf == nil {
		panic("Could not create CloudFlare client?")
		return
	}

	go func() {
		// We periodically grab all the records in CloudFlare to avoid making constant
		// calls to add or remove records that are already either present or absent.
		cf.GetAllRecords()
		for {
			select {
			case <-time.After(20 * time.Second):
				log.Println("Refreshing cf records")
				cf.GetAllRecords()
			}
		}
	}()
	http.HandleFunc("/register", register)
	http.HandleFunc("/unregister", unregister)
	http.ListenAndServe(getPort(), nil)
}

// register is the entry point for peers registering themselves with the service.
// If peers are successfully vetted, they'll be added to the DNS round robin.
func register(w http.ResponseWriter, request *http.Request) {
	reg, err := requestToReg(request)
	if err != nil {
		log.Println("Error converting request ", err)
	} else {
		// We make a flashlight callback directly to
		// the peer. If that works, then we register
		// it in DNS. Our periodic worker process
		// will find it there and will test it again
		// end-to-end with the DNS provider before
		// entering it into the round robin.
		err = callbackToPeer(reg.Ip)
		if err == nil {
			go func() {
				/*
				if reg.Ip == "23.243.192.92" ||
					reg.Ip == "66.69.242.177" ||
					reg.Ip == "83.45.165.48" ||
					reg.Ip == "107.201.128.213" {	
				}
				*/
				//log.Println("Registering peer: ", reg.Ip)
				registerPeer(reg)
			}()
		} else {
			// Note this may not work across platforms, but the intent
			// is to tell the client if the connection was flat out
			// refused as opposed to timed out in order to allow them
			// to configure their router if possible.
			if strings.Contains(err.Error(), "connection refused") {
				// 417 response code.
				w.WriteHeader(http.StatusExpectationFailed)
			} else {
				// 408 response code.
				w.WriteHeader(http.StatusRequestTimeout)
			}
		}
	}
}

// unregister is the HTTP endpoint for removing peers from DNS.
func unregister(w http.ResponseWriter, r *http.Request) {
	reg, err := requestToReg(r)
	if err != nil {
		fmt.Println("Error converting request ", err)
	} else {
		removeFromDns(reg)
	}
}

func removeFromDns(reg *Reg) {
	client := cf.Client

	rec, err := client.RetrieveRecordByName(common.CF_DOMAIN, reg.Name)
	if err != nil {
		log.Println("Error retrieving record! ", err)
		return
	}

	// Make sure we destroy the record on CloudFlare if it
	// didn't work.
	log.Println("Destroying record for: ", reg.Name)
	err = cf.RemoveIpFromRoundRobin(rec.Value, common.ROUNDROBIN)
	if err != nil {
		log.Println("Error deleting peer record from roundrobin! ", err)
	} else {
		//log.Println("Removed DNS record from roundrobin for ", reg.Ip)
	}

	// Destroy it in the peers group as well as the general roundrobin
	err = cf.RemoveIpFromRoundRobin(rec.Value, common.PEERS)
	if err != nil {
		log.Println("Error deleting peer record from roundrobin! ", err)
	} else {
		//log.Println("Removed DNS record from roundrobin for ", reg.Ip)
	}

	err = client.DestroyRecord(common.CF_DOMAIN, rec.Id)
	if err != nil {
		log.Println("Error deleting peer record! ", err)
	} else {
		//log.Println("Removed DNS record for ", reg.Ip)
	}
}

func callbackToPeer(upstreamHost string) error {

	// First just try a plain TCP connection. This is useful because the underlying
	// TCP-level error is consumed in the flashlight layer, and we need that
	// to be accessible on the client side in the logic for deciding whether
	// or not to display the port mapping message.
	conn, err1 := net.DialTimeout("tcp", upstreamHost+":443", 12000*time.Millisecond)
	if err1 != nil {
		//log.Printf("Direct TCP connection failed for IP %s with error %s", upstreamHost, err1)
		return err1
	}
	conn.Close()

	// For now just request again if the above succeeded, as we don't get enough
	// information in the flashlight-level error to determine if the connection
	// was refused, timed-out, or what.
	client := clientFor(upstreamHost)

	resp, err := client.Head("http://www.google.com/humans.txt")
	if err != nil {
		log.Printf("Direct HEAD request failed for IP %v with error %s", upstreamHost, err)
		return err
	} else {
		log.Println("Direct HEAD request succeeded ", upstreamHost)
		defer resp.Body.Close()
		return nil
	}
}

func clientFor(upstreamHost string) *http.Client {
	serverInfo := &client.ServerInfo{
		Host: upstreamHost,
		Port: 443,
		// We use a higher timeout on this initial check
		// because we're just verifying some form of
		// connectivity. We vet peers using a more aggressive
		// check later.
		DialTimeoutMillis:  12000,
		InsecureSkipVerify: true,
	}
	//masquerade := &client.Masquerade{common.MASQUERADE_AS, common.ROOT_CA}
	httpClient := client.HttpClient(serverInfo, nil)

	return httpClient
}

func registerPeer(reg *Reg) {
	if cf.Cached != nil {
		recs := cf.Cached.Response.Recs.Records
		for _, record := range recs {
			if record.Name == reg.Name {
				log.Println("Already registered...returning")
				return 
			}
		}
	} else {
		log.Println("No cached records")
	}
	cr := cloudflare.CreateRecord{Type: "A", Name: reg.Name, Content: reg.Ip}
	rec, err := cf.Client.CreateRecord(common.CF_DOMAIN, &cr)

	if err != nil {
		log.Println("Could not create record? ", err)
		return
	}

	//log.Println("Successfully created record for: ", rec.FullName, rec.Id)

	// Note for some reason CloudFlare seems to ignore the TTL here.
	ur := cloudflare.UpdateRecord{Type: "A", Name: reg.Name, Content: reg.Ip, Ttl: "360", ServiceMode: "1"}

	err = cf.Client.UpdateRecord(common.CF_DOMAIN, rec.Id, &ur)

	if err != nil {
		log.Println("Could not update record? ", err)
	}
}

func requestToReg(r *http.Request) (*Reg, error) {
	name := r.FormValue("name")
	//log.Println("Read name: ", name)
	ip := clientIpFor(r)
	portString := r.FormValue("port")

	port := 0
	if portString == "" {
		// Could be an unregister call
		port = 0
	} else {
		converted, err := strconv.Atoi(portString)
		if err != nil {
			// handle error
			fmt.Println(err)
			return nil, err
		}
		port = converted
	}

	// If they're actually reporting an IP (it's a register call), make
	// sure the port is 443
	if len(ip) > 0 && port != 443 {
		log.Println("Ignoring port not on 443")
		return nil, fmt.Errorf("Bad port: %d", port)
	}
	reg := &Reg{name, ip, port}

	return reg, nil
}

func clientIpFor(req *http.Request) string {
	// If we're running in production on Heroku, use the IP of the client.
	// Otherwise use whatever IP is passed to the API.
	if onHeroku() {
		// Client requested their info
		clientIp := req.Header.Get("X-Forwarded-For")
		if clientIp == "" {
			clientIp = strings.Split(req.RemoteAddr, ":")[0]
		}
		// clientIp may contain multiple ips, use the first
		ips := strings.Split(clientIp, ",")
		return strings.TrimSpace(ips[0])
	} else {
		return req.FormValue("ip")
	}
}

// Get the Port from the environment so we can run on Heroku
func getPort() string {
	var port = os.Getenv("PORT")
	// Set a default port if there is nothing in the environment
	if port == "" {
		port = "7777"
		fmt.Println("INFO: No PORT environment variable detected, defaulting to " + port)
	}
	return ":" + port
}

func onHeroku() bool {
	var dyno = os.Getenv("DYNO")
	return dyno != ""
}
