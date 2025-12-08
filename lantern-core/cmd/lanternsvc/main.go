//go:build windows

package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"runtime"
	"runtime/debug"
	"strings"
	"syscall"
	"unsafe"

	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/lantern-outline/lantern-core/wintunmgr"
	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"

	rcommon "github.com/getlantern/radiance/common"
)

const (
	adapterName     = "Lantern"
	poolName        = "Lantern"
	servicePipeName = `\\.\pipe\LanternService`
)

func guard(where string) {
	if r := recover(); r != nil {
		buf := make([]byte, 1<<20)
		n := runtime.Stack(buf, true)
		slog.Error("PANIC in "+where, "error", r, "stack", string(buf[:n]))
	}
}

func init() {
	debug.SetTraceback("all")
	debug.SetPanicOnFault(true)
}

func main() {
	// Initialize radiance to ensure our directories and logging are set up.
	rcommon.Init("", "", "debug")
	consoleMode := flag.Bool("console", false, "Run in console mode instead of Windows service")
	flag.Parse()

	isService, err := isWindowsService()
	if err != nil {
		slog.Error("Failed to determine if running as Windows service", "error", err)
		return
	}

	if *consoleMode || !isService {
		runConsole()
		return
	}

	// let SCM specify the service name
	if err := svc.Run(common.WindowsServiceName, &lanternHandler{}); err != nil {
		slog.Error("Service failed", "error", err)
	}
}

func newWindowsService() (*wintunmgr.Manager, *wintunmgr.Service, error) {
	wt := wintunmgr.New(adapterName, poolName, nil)
	s, err := wintunmgr.NewService(wintunmgr.ServiceOptions{
		PipeName: servicePipeName,
	}, wt)
	if err != nil {
		return nil, nil, fmt.Errorf("creating wintunmgr service: %w", err)
	}
	return wt, s, nil
}

func runConsole() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	slog.Debug("Starting " + common.WindowsServiceName + " in console mode (pid=" + fmt.Sprint(os.Getpid()) + ")")

	defer guard("runConsole")

	_, s, err := newWindowsService()
	if err != nil {
		slog.Error("Failed to create new Windows service", "error", err)
		return
	}

	if err := s.Start(ctx); err != nil {
		slog.Error("Failed to start Windows service", "error", err)
		return
	}
}

type lanternHandler struct{}

func (h *lanternHandler) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (svcSpecificEC bool, exitCode uint32) {
	const accepts = svc.AcceptStop | svc.AcceptShutdown

	defer guard("lanternHandler.Execute")

	changes <- svc.Status{State: svc.StartPending, WaitHint: 30 * 1000}

	// Report Running to SCM
	changes <- svc.Status{State: svc.Running, Accepts: accepts}

	ctx, cancel := context.WithCancel(context.Background())

	started := make(chan error, 1)
	go func() {
		defer guard("service worker")
		_, s, err := newWindowsService()
		if err == nil {
			err = s.Start(ctx)
		}
		started <- err
	}()

	for {
		select {
		case c := <-r:
			switch c.Cmd {
			case svc.Interrogate:
				changes <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}
				cancel()
				if err := <-started; err != nil {
					slog.Error("service worker exited with error on stop", "error", err)
					changes <- svc.Status{State: svc.Stopped}
					return false, 1
				}
				changes <- svc.Status{State: svc.Stopped}
				return false, 0
			}
		case err := <-started:
			if err != nil {
				slog.Error("service worker exited unexpectedly", "error", err)
				changes <- svc.Status{State: svc.Stopped}
				cancel()
				return false, 1
			}
		}
	}
}

// Copyright 2023-present Datadog, Inc.
// Licensed under the Apache License, Version 2.0 (the "License");
// https://github.com/DataDog/datadog-agent/blob/46740e82ef40a04c4be545ed8c16a4b0d1f046cf/pkg/util/winutil/servicemain/servicemain.go#L128
func isWindowsService() (bool, error) {
	var currentProcess windows.PROCESS_BASIC_INFORMATION

	infoSize := uint32(unsafe.Sizeof(currentProcess))

	err := windows.NtQueryInformationProcess(windows.CurrentProcess(), windows.ProcessBasicInformation, unsafe.Pointer(&currentProcess), infoSize, &infoSize)
	if err != nil {
		return false, err
	}

	var parentProcess *windows.SYSTEM_PROCESS_INFORMATION

	for infoSize = uint32((unsafe.Sizeof(*parentProcess) + unsafe.Sizeof(uintptr(0))) * 1024); ; {
		parentProcess = (*windows.SYSTEM_PROCESS_INFORMATION)(unsafe.Pointer(&make([]byte, infoSize)[0]))

		err = windows.NtQuerySystemInformation(windows.SystemProcessInformation, unsafe.Pointer(parentProcess), infoSize, &infoSize)
		if err == nil {
			break
		} else if !errors.Is(err, windows.STATUS_INFO_LENGTH_MISMATCH) {
			return false, err
		}
	}

	for ; ; parentProcess = (*windows.SYSTEM_PROCESS_INFORMATION)(unsafe.Pointer(uintptr(unsafe.Pointer(parentProcess)) + uintptr(parentProcess.NextEntryOffset))) {
		if parentProcess.UniqueProcessID == currentProcess.InheritedFromUniqueProcessId {
			return strings.EqualFold("services.exe", parentProcess.ImageName.String()), nil
		}

		if parentProcess.NextEntryOffset == 0 {
			break
		}
	}

	return false, nil
}
