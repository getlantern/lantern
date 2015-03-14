package main

import (
	"time"
)

const (
	listenAddr        = ":9197"
	githubNamespace   = "getlantern"
	githubRepo        = "autoupdate-server"
	githubRefreshTime = time.Minute * 30
	publicAddr        = "http://127.0.0.1:9197/"
	patchesDirectory  = "./patches/"
)
