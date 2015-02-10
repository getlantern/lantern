/*
Package systray is a cross platfrom Go library to place an icon and menu in the notification area.
Supports Windows, Mac OSX and Linux currently.
Methods can be called from any goroutine except Run(), which should be called at the very beginning of main() to lock at main thread.
*/
package systray

/*
#cgo linux pkg-config: gtk+-3.0 appindicator3-0.1
#cgo windows CFLAGS: -DWIN32 -DUNICODE -D_UNICODE
#cgo darwin CFLAGS: -DDARWIN -x objective-c -fobjc-arc
#cgo darwin LDFLAGS: -framework Cocoa

#include "systray.h"
*/
import "C"
import (
	"code.google.com/p/go-uuid/uuid"
	"runtime"
	"sync"
	"unsafe"
)

// MenuItem is used to keep track each menu item of systray
// Don't create it directly, use the one systray.AddMenuItem() returned
type MenuItem struct {
	// ClickedCh is the channel which will be notified when the menu item is clicked
	ClickedCh chan interface{}

	// id uniquely identify a menu item, not supposed to be modified
	id string
	// title is the text shown on menu item
	title string
	// tooltip is the text shown when pointing to menu item
	tooltip string
	// disabled menu item is grayed out and has no effect when clicked
	disabled bool
	// checked menu item has a tick before the title
	checked bool
}

var (
	readyCh       = make(chan interface{})
	clickedCh     = make(chan interface{})
	menuItems     = make(map[string]*MenuItem)
	menuItemsLock sync.RWMutex
)

// Run initializes GUI and starts the event loop, then invokes the onReady
// callback.
// It blocks until systray.Quit() is called.
// Should be called at the very beginning of main() to lock at main thread.
func Run(onReady func()) {
	runtime.LockOSThread()
	go func() {
		<-readyCh
		onReady()
	}()

	C.nativeLoop()
}

// Quit the systray and whole app
func Quit() {
	C.quit()
}

// SetIcon sets the systray icon.
// iconBytes should be the content of .ico for windows and .ico/.jpg/.png
// for other platforms.
func SetIcon(iconBytes []byte) {
	cstr := (*C.char)(unsafe.Pointer(&iconBytes[0]))
	C.setIcon(cstr, (C.int)(len(iconBytes)))
}

// SetTitle sets the systray title, only available on Mac.
func SetTitle(title string) {
	C.setTitle(C.CString(title))
}

// SetTitle sets the systray tooltip to display on mouse hover of the tray icon,
// only available on Mac.
func SetTooltip(tooltip string) {
	C.setTooltip(C.CString(tooltip))
}

// Add menu item with designated title and tooltip, returning a channel that
// notifies whenever that menu item has been clicked.
//
// Menu items are keyed to an id. If the same id is added twice, the 2nd one
// overwrites the first.
//
// AddMenuItem can be safely invoked from different goroutines.
func AddMenuItem(title string, tooltip string) *MenuItem {
	id := uuid.New()
	item := &MenuItem{nil, id, title, tooltip, false, false}
	item.ClickedCh = make(chan interface{})
	item.update()
	return item
}

func (item *MenuItem) SetTitle(title string) {
	item.title = title
	item.update()
}

func (item *MenuItem) SetTooltip(tooltip string) {
	item.tooltip = tooltip
	item.update()
}

func (item *MenuItem) Disabled() bool {
	return item.disabled
}

func (item *MenuItem) Enable() {
	item.disabled = false
	item.update()
}

func (item *MenuItem) Disable() {
	item.disabled = true
	item.update()
}

func (item *MenuItem) Checked() bool {
	return item.checked
}

func (item *MenuItem) Check() {
	item.checked = true
	item.update()
}

func (item *MenuItem) Uncheck() {
	item.checked = false
	item.update()
}

// update propogates changes on a menu item to systray
func (item *MenuItem) update() {
	menuItemsLock.Lock()
	defer menuItemsLock.Unlock()
	menuItems[item.id] = item
	var disabled C.short = 0
	if item.disabled {
		disabled = 1
	}
	var checked C.short = 0
	if item.checked {
		checked = 1
	}
	C.add_or_update_menu_item(
		C.CString(item.id),
		C.CString(item.title),
		C.CString(item.tooltip),
		disabled,
		checked,
	)
}

//export systray_ready
func systray_ready() {
	readyCh <- nil
}

//export systray_menu_item_selected
func systray_menu_item_selected(cId *C.char) {
	id := C.GoString(cId)
	menuItemsLock.RLock()
	item := menuItems[id]
	menuItemsLock.RUnlock()
	select {
	case item.ClickedCh <- nil:
	// in case no one waiting for the channel
	default:
	}
}
