//go:build !ios
// +build !ios

package main

func startTun2SocksImpl() error {
	return tunnel.Run()
}
