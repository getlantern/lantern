/*
Package systray is a cross platfrom Go library to place an icon and menu in the notification area.
Supports Windows, Mac OSX and Linux currently.
Methods can be called from any goroutine except Run(), which should be called at the very beginning of main() to lock at main thread.
*/
package systray

import (
	"runtime"
	"sync"
	"sync/atomic"

	"github.com/getlantern/golog"
)

// MenuItem is used to keep track each menu item of systray
// Don't create it directly, use the one systray.AddMenuItem() returned
type MenuItem struct {
	// ClickedCh is the channel which will be notified when the menu item is clicked
	ClickedCh chan interface{}

	// id uniquely identify a menu item, not supposed to be modified
	id int32
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
	log = golog.LoggerFor("systray")

	readyCh       = make(chan interface{})
	clickedCh     = make(chan interface{})
	menuItems     = make(map[int32]*MenuItem)
	menuItemsLock sync.RWMutex

	currentId int32
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

	nativeLoop()
}

// Quit the systray
func Quit() {
	quit()
}

// Add menu item with designated title and tooltip, returning a channel that
// notifies whenever that menu item has been clicked.
//
// Menu items are keyed to an id. If the same id is added twice, the 2nd one
// overwrites the first.
//
// AddMenuItem can be safely invoked from different goroutines.
func AddMenuItem(title string, tooltip string) *MenuItem {
	id := atomic.AddInt32(&currentId, 1)
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
	addOrUpdateMenuItem(item)
}

func systrayReady() {
	readyCh <- nil
}

func systrayMenuItemSelected(id int32) {
	menuItemsLock.RLock()
	item := menuItems[id]
	menuItemsLock.RUnlock()
	select {
	case item.ClickedCh <- nil:
	// in case no one waiting for the channel
	default:
	}
}
