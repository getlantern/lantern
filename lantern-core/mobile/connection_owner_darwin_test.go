//go:build darwin

package mobile

import (
	"net"
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

func TestFindConnectionOwnerDarwinLoopback(t *testing.T) {
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("net.Listen: %v", err)
	}
	defer ln.Close()

	accepted := make(chan net.Conn, 1)
	go func() {
		conn, acceptErr := ln.Accept()
		if acceptErr == nil {
			accepted <- conn
		}
	}()

	client, err := net.Dial("tcp4", ln.Addr().String())
	if err != nil {
		t.Fatalf("net.Dial: %v", err)
	}
	defer client.Close()

	server := <-accepted
	defer server.Close()

	src := client.LocalAddr().(*net.TCPAddr)
	dst := client.RemoteAddr().(*net.TCPAddr)

	owner, err := FindConnectionOwner(
		int32(syscall.IPPROTO_TCP),
		src.IP.String(),
		int32(src.Port),
		dst.IP.String(),
		int32(dst.Port),
	)
	if err != nil {
		t.Fatalf("FindConnectionOwner() error = %v", err)
	}
	if owner == nil || owner.ProcessPath == "" {
		t.Fatalf("FindConnectionOwner() returned empty ProcessPath: %+v", owner)
	}

	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("os.Executable: %v", err)
	}
	resolvedExe, err := filepath.EvalSymlinks(exe)
	if err == nil {
		exe = resolvedExe
	}
	resolvedGot, err := filepath.EvalSymlinks(owner.ProcessPath)
	if err == nil {
		owner.ProcessPath = resolvedGot
	}
	if owner.ProcessPath != exe {
		t.Fatalf("FindConnectionOwner().ProcessPath = %q, want %q", owner.ProcessPath, exe)
	}
}
