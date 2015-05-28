// Copyright 2011 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build appengine

package main

// This file replaces main.go when running godoc under app-engine.
// See README.godoc-app for details.

import (
	"archive/zip"
	"log"
	"path"
	"regexp"

	"golang.org/x/tools/godoc"
	"golang.org/x/tools/godoc/static"
	"golang.org/x/tools/godoc/vfs"
	"golang.org/x/tools/godoc/vfs/mapfs"
	"golang.org/x/tools/godoc/vfs/zipfs"
)

func init() {
	playEnabled = true

	log.Println("initializing godoc ...")
	log.Printf(".zip file   = %s", zipFilename)
	log.Printf(".zip GOROOT = %s", zipGoroot)
	log.Printf("index files = %s", indexFilenames)

	goroot := path.Join("/", zipGoroot) // fsHttp paths are relative to '/'

	// read .zip file and set up file systems
	const zipfile = zipFilename
	rc, err := zip.OpenReader(zipfile)
	if err != nil {
		log.Fatalf("%s: %s\n", zipfile, err)
	}
	// rc is never closed (app running forever)
	fs.Bind("/", zipfs.New(rc, zipFilename), goroot, vfs.BindReplace)
	fs.Bind("/lib/godoc", mapfs.New(static.Files), "/", vfs.BindReplace)

	corpus := godoc.NewCorpus(fs)
	corpus.Verbose = false
	corpus.MaxResults = 10000 // matches flag default in main.go
	corpus.IndexEnabled = true
	corpus.IndexFiles = indexFilenames
	if err := corpus.Init(); err != nil {
		log.Fatal(err)
	}
	corpus.IndexDirectory = indexDirectoryDefault
	go corpus.RunIndexer()

	pres = godoc.NewPresentation(corpus)
	pres.TabWidth = 8
	pres.ShowPlayground = true
	pres.ShowExamples = true
	pres.DeclLinks = true
	pres.NotesRx = regexp.MustCompile("BUG")

	readTemplates(pres, true)
	registerHandlers(pres)

	log.Println("godoc initialization complete")
}
