package main // import "9fans.net/go/acme/Dict"

import (
	"flag"
	"log"

	"9fans.net/go/acme"
	"golang.org/x/net/dict"
)

var dictx = flag.String("d", "", "dictionary")
var server = flag.String("s", "dict.org:dict", "server")
var lookc = make(chan string)
var d *dict.Client
var dicts []dict.Dict

func main() {
	w, err := acme.New()
	if err != nil {
		log.Fatal(err)
	}
	w.Name("/dict/")
	d, err = dict.Dial("tcp", "216.93.242.2:dict")
	if err != nil {
		w.Write("body", []byte(err.Error()))
		return
	}
	w.Ctl("clean")
	go func() {
		dicts, err = d.Dicts()
		if err != nil {
			w.Write("body", []byte(err.Error()))
			return
		}
		for _, dict := range dicts {
			w.Fprintf("body", "%s\t%s\n", dict.Name, dict.Desc)
		}
	}()
	for word := range events(w) {
		go lookup(word)
	}
}

func lookup(word string) {
	defs, err := d.Define("!", word)
	if err != nil {
		log.Print(err)
		return
	}
	for _, def := range defs {
		go wordwin(def)
	}
}

func wordwin(def *dict.Defn) {
	w, err := acme.New()
	if err != nil {
		log.Fatal(err)
	}
	w.Name("/dict/%s/%s", def.Dict.Name, def.Word)
	w.Write("body", def.Text)
	w.Ctl("clean")
	for word := range events(w) {
		go lookup(word)
	}
}

func events(w *acme.Win) <-chan string {
	c := make(chan string, 10)
	go func() {
		for e := range w.EventChan() {
			switch e.C2 {
			case 'x', 'X': // execute
				if string(e.Text) == "Del" {
					w.Ctl("delete")
				}
				w.WriteEvent(e)
			case 'l', 'L': // look
				w.Ctl("clean")
				c <- string(e.Text)
			}
		}
		w.CloseFiles()
		close(c)
	}()
	return c
}
