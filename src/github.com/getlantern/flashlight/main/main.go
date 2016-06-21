// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"net/http"
	_ "net/http/pprof"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"syscall"

	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"
	"github.com/mitchellh/panicwrap"

	"github.com/getlantern/flashlight/app"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/ui"
)

var (
	log = golog.LoggerFor("flashlight")
)

func main() {
	// systray requires the goroutine locked with main thread, or the whole
	// application will crash.
	runtime.LockOSThread()
	parseFlags()

	a := &app.App{
		ShowUI: !*headless,
		Flags:  flagsAsMap(),
	}
	a.Init()

	// panicwrap works by re-executing the running program (retaining arguments,
	// environmental variables, etc.) and monitoring the stderr of the program.
	exitStatus, err := panicwrap.BasicWrap(
		func(output string) {
			a.LogPanicAndExit(output)
		})
	if err != nil {
		// Something went wrong setting up the panic wrapper. This won't be
		// captured by panicwrap
		// At this point, continue execution without panicwrap support. There
		// are known cases where panicwrap will fail to fork, such as Windows
		// GUI app
		log.Errorf("Error setting up panic wrapper: %v", err)
	} else {
		// If exitStatus >= 0, then we're the parent process.
		if exitStatus >= 0 {
			os.Exit(exitStatus)
		}
	}

	if *help {
		flag.Usage()
		log.Fatal("Wrong arguments")
	}

	if *pprofAddr != "" {
		go func() {
			log.Debugf("Starting pprof page at http://%s/debug/pprof", *pprofAddr)
			if err := http.ListenAndServe(*pprofAddr, nil); err != nil {
				log.Error(err)
			}
		}()
	}

	client.ForceChainedProxyAddr = *forceProxyAddr
	client.ForceAuthToken = *forceAuthToken

	if a.ShowUI {
		runOnSystrayReady(_main(a))
	} else {
		log.Debug("Running headless")
		_main(a)()
	}
}

func _main(a *app.App) func() {
	return func() {
		if err := doMain(a); err != nil {
			log.Error(err)
		}
		log.Debug("Lantern stopped")

		os.Exit(0)
	}
}

func doMain(a *app.App) error {
	if err := logging.EnableFileLogging(""); err != nil {
		return err
	}

	// Schedule cleanup actions
	handleSignals(a)
	a.AddExitFunc(func() {
		if err := logging.Close(); err != nil {
			log.Errorf("Error closing log: %v", err)
		}
	})
	a.AddExitFunc(quitSystray)

	if a.ShowUI {
		lang := a.GetSetting("language").(string)
		i18nInit(lang)
		if err := configureSystemTray(a); err != nil {
			return err
		}
		a.OnSettingChange("language", func(lang interface{}) {
			refreshSystray(lang.(string))
		})

	}

	return a.Run()
}

func i18nInit(locale string) {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	if err := i18n.SetLocale(locale); err != nil {
		log.Debugf("i18n.SetLocale(%s) failed, fallback to OS default: %q", locale, err)
		if err := i18n.UseOSLocale(); err != nil {
			log.Debugf("i18n.UseOSLocale: %q", err)
		}
	}
}

func parseFlags() {
	args := os.Args[1:]
	// On OS X, the first time that the program is run after download it is
	// quarantined.  OS X will ask the user whether or not it's okay to run the
	// program.  If the user says that it's okay, OS X will run the program but
	// pass an extra flag like -psn_0_1122578.  flag.Parse() fails if it sees
	// any flags that haven't been declared, so we remove the extra flag.
	if len(os.Args) == 2 && strings.HasPrefix(os.Args[1], "-psn") {
		log.Debugf("Ignoring extra flag %v", os.Args[1])
		args = []string{}
	}
	// Note - we can ignore the returned error because CommandLine.Parse() will
	// exit if it fails.
	_ = flag.CommandLine.Parse(args)
}

// Handle system signals for clean exit
func handleSignals(a *app.App) {
	c := make(chan os.Signal, 1)
	signal.Notify(c,
		syscall.SIGHUP,
		syscall.SIGINT,
		syscall.SIGTERM,
		syscall.SIGQUIT)
	go func() {
		s := <-c
		log.Debugf("Got signal \"%s\", exiting...", s)
		a.Exit(nil)
	}()
}
