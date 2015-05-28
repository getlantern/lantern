// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Acmego watches acme for .go files being written.
// Each time a .go file is written, acmego checks whether the
// import block needs adjustment. If so, it makes the changes
// in the window body but does not write the file.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"unicode/utf8"

	"9fans.net/go/acme"
)

var gofmt = flag.Bool("f", false, "run gofmt on the entire file after Put")

func main() {
	flag.Parse()
	l, err := acme.Log()
	if err != nil {
		log.Fatal(err)
	}

	for {
		event, err := l.Read()
		if err != nil {
			log.Fatal(err)
		}
		if event.Name != "" && event.Op == "put" && strings.HasSuffix(event.Name, ".go") {
			reformat(event.ID, event.Name)
		}
	}
}

func reformat(id int, name string) {
	w, err := acme.Open(id, nil)
	if err != nil {
		log.Print(err)
		return
	}
	defer w.CloseFiles()

	old, err := ioutil.ReadFile(name)
	if err != nil {
		//log.Print(err)
		return
	}
	new, err := exec.Command("goimports", name).CombinedOutput()
	if err != nil {
		// Probably a syntax error, use the compiler for better message.
		// For now use 'go build file.go' and strip the package header.
		// We run it in /var/run so that paths do not get shortened
		// (assuming /var/run exists and no one is editing go files under that path).
		// A better fix to both would be to use go tool 6g, but we don't know
		// whether 6g is the right architecture. Could parse 'go env' output.
		// Or maybe the go command should have 'go tool compile' and 'go tool link'.
		cmd := exec.Command("go", "build", name)
		cmd.Dir = "/var/run"
		out, _ := cmd.CombinedOutput()
		start := []byte("# command-line-arguments\n")
		if !bytes.HasPrefix(out, start) {
			fmt.Fprintf(os.Stderr, "goimports %s: %v\n%s", name, err, new)
			return
		}
		fmt.Fprintf(os.Stderr, "%s", out)
		return
	}

	if bytes.Equal(old, new) {
		return
	}

	if !*gofmt {
		oldTop, err := readImports(bytes.NewReader(old), true)
		if err != nil {
			//log.Print(err)
			return
		}
		newTop, err := readImports(bytes.NewReader(new), true)
		if err != nil {
			//log.Print(err)
			return
		}
		if bytes.Equal(oldTop, newTop) {
			return
		}
		w.Addr("0,#%d", utf8.RuneCount(oldTop))
		w.Write("data", newTop)
		return
	}

	f, err := ioutil.TempFile("", "acmego")
	if err != nil {
		log.Print(err)
		return
	}
	if _, err := f.Write(new); err != nil {
		log.Print(err)
		return
	}
	tmp := f.Name()
	f.Close()
	defer os.Remove(tmp)

	diff, _ := exec.Command("9", "diff", name, tmp).CombinedOutput()

	w.Write("ctl", []byte("mark"))
	w.Write("ctl", []byte("nomark"))
	diffLines := strings.Split(string(diff), "\n")
	for i := len(diffLines) - 1; i >= 0; i-- {
		line := diffLines[i]
		if line == "" {
			continue
		}
		if line[0] == '<' || line[0] == '-' || line[0] == '>' {
			continue
		}
		j := 0
		for j < len(line) && line[j] != 'a' && line[j] != 'c' && line[j] != 'd' {
			j++
		}
		if j >= len(line) {
			log.Printf("cannot parse diff line: %q", line)
			break
		}
		oldStart, oldEnd := parseSpan(line[:j])
		newStart, newEnd := parseSpan(line[j+1:])
		if oldStart == 0 || newStart == 0 {
			continue
		}
		switch line[j] {
		case 'a':
			err := w.Addr("%d+#0", oldStart)
			if err != nil {
				log.Print(err)
				break
			}
			w.Write("data", findLines(new, newStart, newEnd))
		case 'c':
			err := w.Addr("%d,%d", oldStart, oldEnd)
			if err != nil {
				log.Print(err)
				break
			}
			w.Write("data", findLines(new, newStart, newEnd))
		case 'd':
			err := w.Addr("%d,%d", oldStart, oldEnd)
			if err != nil {
				log.Print(err)
				break
			}
			w.Write("data", nil)
		}
	}
}

func parseSpan(text string) (start, end int) {
	i := strings.Index(text, ",")
	if i < 0 {
		n, err := strconv.Atoi(text)
		if err != nil {
			log.Printf("cannot parse span %q", text)
			return 0, 0
		}
		return n, n
	}
	start, err1 := strconv.Atoi(text[:i])
	end, err2 := strconv.Atoi(text[i+1:])
	if err1 != nil || err2 != nil {
		log.Printf("cannot parse span %q", text)
		return 0, 0
	}
	return start, end
}

func findLines(text []byte, start, end int) []byte {
	i := 0

	start--
	for ; i < len(text) && start > 0; i++ {
		if text[i] == '\n' {
			start--
			end--
		}
	}
	startByte := i
	for ; i < len(text) && end > 0; i++ {
		if text[i] == '\n' {
			end--
		}
	}
	endByte := i
	return text[startByte:endByte]
}
