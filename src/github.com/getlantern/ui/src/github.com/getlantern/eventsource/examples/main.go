package main

import (
	"net/http"
	"github.com/msgehard/eventsource"
	"time"
	"html/template"
	"fmt"
)

const homepageHtml = `
<html>
  <head>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
  	<script>
		var source = new EventSource("/events");
		source.addEventListener('message', function(e) {
		  console.log(e);
		  $("#messages").append("<p>" + e.data + "</p>");
		}, false);
  	</script>
  </head>
  <body>
    Look at all of the messages from the server:
    <div id="messages"/>
  </body>
</html>
`

var homepageTemplate = template.Must(template.New("home").Parse(homepageHtml))

func eventHandler(es *eventsource.Conn) {
	fmt.Println("Client connected.")
	for {
		select {
		case <-time.After(2*time.Second):
			es.Write("Hello from the server!")
			fmt.Println("Sent message.")
		case <-es.CloseNotify():
			fmt.Println("Client went away.")
			return
		}
	}
}

func homePage(w http.ResponseWriter, req *http.Request) {
	homepageTemplate.Execute(w, nil)
}

func main() {
	serverAddress := ":9001"
	fmt.Printf("Starting app at %s\n", serverAddress)
	http.Handle("/events", eventsource.Handler(eventHandler))
	http.HandleFunc("/", homePage)
	http.ListenAndServe(serverAddress, nil)
}
