// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

// Small test app used by app/app_test.go.
package main

import (
	"log"
	"net"

	"golang.org/x/mobile/app"
	"golang.org/x/mobile/app/internal/apptest"
	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/touch"
)

func main() {
	app.Main(func(a app.App) {
		addr := "127.0.0.1:" + apptest.Port
		log.Printf("addr: %s", addr)

		conn, err := net.Dial("tcp", addr)
		if err != nil {
			log.Fatal(err)
		}
		defer conn.Close()
		log.Printf("dialled")
		comm := &apptest.Comm{
			Conn:   conn,
			Fatalf: log.Panicf,
			Printf: log.Printf,
		}

		comm.Send("hello_from_testapp")
		comm.Recv("hello_from_host")

		sendPainting := false
		var c config.Event
		for e := range a.Events() {
			switch e := app.Filter(e).(type) {
			case lifecycle.Event:
				switch e.Crosses(lifecycle.StageVisible) {
				case lifecycle.CrossOn:
					comm.Send("lifecycle_visible")
					sendPainting = true
				case lifecycle.CrossOff:
					comm.Send("lifecycle_not_visible")
				}
			case config.Event:
				c = e
				comm.Send("config", c.PixelsPerPt)
			case paint.Event:
				if sendPainting {
					comm.Send("paint")
					sendPainting = false
				}
				a.EndPaint(e)
			case touch.Event:
				comm.Send("touch", e.Type, e.X, e.Y)
			}
		}
	})
}
