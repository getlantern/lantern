package systray

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"syscall"
	"unsafe"
)

var (
	iconFiles = make([]*os.File, 0)
	dllDir    = path.Join(os.Getenv("APPDATA"), "systray")
	dllFile   = path.Join(dllDir, "systray.dll")

	mod                      = syscall.NewLazyDLL(dllFile)
	_nativeLoop              = mod.NewProc("nativeLoop")
	_quit                    = mod.NewProc("quit")
	_setIcon                 = mod.NewProc("setIcon")
	_setTitle                = mod.NewProc("setTitle")
	_setTooltip              = mod.NewProc("setTooltip")
	_add_or_update_menu_item = mod.NewProc("add_or_update_menu_item")
)

func init() {
	// Write DLL to file
	b, err := Asset("systray.dll")
	if err != nil {
		panic(fmt.Errorf("Unable to read systray.dll: %v", err))
	}

	err = os.MkdirAll(dllDir, 0755)
	if err != nil {
		panic(fmt.Errorf("Unable to create directory %v to hold systray.dll: %v", dllDir, err))
	}

	err = ioutil.WriteFile(dllFile, b, 0644)
	if err != nil {
		panic(fmt.Errorf("Unable to save systray.dll to %v: %v", dllFile, err))
	}
}

func nativeLoop() {
	_nativeLoop.Call(
		syscall.NewCallbackCDecl(systray_ready),
		syscall.NewCallbackCDecl(systray_menu_item_selected))
}

func quit() {
	_quit.Call()
	for _, f := range iconFiles {
		err := os.Remove(f.Name())
		if err != nil {
			log.Debugf("Unable to delete temporary icon file %v: %v", f.Name(), err)
		}
	}
}

// SetIcon sets the systray icon.
// iconBytes should be the content of .ico for windows and .ico/.jpg/.png
// for other platforms.
func SetIcon(iconBytes []byte) {
	f, err := ioutil.TempFile("", "systray_temp_icon")
	if err != nil {
		log.Errorf("Unable to create temp icon: %v", err)
		return
	}
	defer f.Close()
	_, err = f.Write(iconBytes)
	if err != nil {
		log.Errorf("Unable to write icon to temp file %v: %v", f.Name(), f)
		return
	}
	// Need to close file before we load it to make sure contents is flushed.
	f.Close()
	u16, name, err := strPtr(f.Name())
	if err != nil {
		log.Errorf("Unable to convert name to string pointer: %v", err)
		return
	}
	_setIcon.Call(name)
	noop(u16)
}

// SetTitle sets the systray title, only available on Mac.
func SetTitle(title string) {
	// do nothing
}

// SetTooltip sets the systray tooltip to display on mouse hover of the tray icon,
// only available on Mac and Windows.
func SetTooltip(tooltip string) {
	u16, t, err := strPtr(tooltip)
	if err != nil {
		log.Errorf("Unable to convert tooltip to string pointer: %v", err)
		return
	}
	_setTooltip.Call(t)
	noop(u16)
}

func addOrUpdateMenuItem(item *MenuItem) {
	var disabled = 0
	if item.disabled {
		disabled = 1
	}
	var checked = 0
	if item.checked {
		checked = 1
	}
	u16a, title, err := strPtr(item.title)
	if err != nil {
		log.Errorf("Unable to convert title to string pointer: %v", err)
		return
	}
	u16b, tooltip, err := strPtr(item.tooltip)
	if err != nil {
		log.Errorf("Unable to convert tooltip to string pointer: %v", err)
		return
	}
	_add_or_update_menu_item.Call(
		uintptr(item.id),
		title,
		tooltip,
		uintptr(disabled),
		uintptr(checked),
	)
	noop(u16a)
	noop(u16b)
}

// strPrt converts a Go string into a wchar_t*
func strPtr(s string) ([]uint16, uintptr, error) {
	u16, err := syscall.UTF16FromString(s)
	if err != nil {
		return nil, 0, err
	}
	return u16, uintptr(unsafe.Pointer(&u16[0])), nil
}

// noop does nothing. We just call it so that we're doing something with the u16
// variable, which we just hang on to to prevent it being gc'd.
func noop(u16 []uint16) {
	// do nothing
}

// systray_ready takes an ignored parameter just so we can compile a callback
// (for some reason in Go 1.4.x, syscall.NewCallback panics if there's no
// parameter to the function).
func systray_ready(ignore uintptr) uintptr {
	systrayReady()
	return 0
}

func systray_menu_item_selected(id uintptr) uintptr {
	systrayMenuItemSelected(int32(id))
	return 0
}
