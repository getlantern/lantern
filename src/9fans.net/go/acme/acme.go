// Package acme is a simple interface for interacting with acme windows.
//
// Many of the functions in this package take a format string and optional
// parameters.  In the documentation, the notation format, ... denotes the result
// of formatting the string and arguments using fmt.Sprintf.
package acme // import "9fans.net/go/acme"

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"strconv"
	"strings"
	"sync"

	"9fans.net/go/plan9"
	"9fans.net/go/plan9/client"
)

// A Win represents a single acme window and its control files.
type Win struct {
	id         int
	ctl        *client.Fid
	tag        *client.Fid
	body       *client.Fid
	addr       *client.Fid
	event      *client.Fid
	data       *client.Fid
	xdata      *client.Fid
	ebuf       *bufio.Reader
	c          chan *Event
	next, prev *Win
	buf        []byte
	e2, e3, e4 Event
}

var windows, last *Win

var fsys *client.Fsys
var fsysErr error
var fsysOnce sync.Once

func mountAcme() {
	fsys, fsysErr = client.MountService("acme")
}

// New creates a new window.
func New() (*Win, error) {
	fsysOnce.Do(mountAcme)
	if fsysErr != nil {
		return nil, fsysErr
	}
	fid, err := fsys.Open("new/ctl", plan9.ORDWR)
	if err != nil {
		return nil, err
	}
	buf := make([]byte, 100)
	n, err := fid.Read(buf)
	if err != nil {
		fid.Close()
		return nil, err
	}
	a := strings.Fields(string(buf[0:n]))
	if len(a) == 0 {
		fid.Close()
		return nil, errors.New("short read from acme/new/ctl")
	}
	id, err := strconv.Atoi(a[0])
	if err != nil {
		fid.Close()
		return nil, errors.New("invalid window id in acme/new/ctl: " + a[0])
	}
	return Open(id, fid)
}

type WinInfo struct {
	ID   int
	Name string
}

// A LogReader provides read access to the acme log file.
type LogReader struct {
	f   *client.Fid
	buf [8192]byte
}

func (r *LogReader) Close() error {
	return r.f.Close()
}

// A LogEvent is a single event in the acme log file.
type LogEvent struct {
	ID   int
	Op   string
	Name string
}

// Read reads an event from the acme log file.
func (r *LogReader) Read() (LogEvent, error) {
	n, err := r.f.Read(r.buf[:])
	if err != nil {
		return LogEvent{}, err
	}
	f := strings.SplitN(string(r.buf[:n]), " ", 3)
	if len(f) != 3 {
		return LogEvent{}, fmt.Errorf("malformed log event")
	}
	id, _ := strconv.Atoi(f[0])
	op := f[1]
	name := f[2]
	name = strings.TrimSpace(name)
	return LogEvent{id, op, name}, nil
}

// Log returns a reader reading the acme/log file.
func Log() (*LogReader, error) {
	fsysOnce.Do(mountAcme)
	if fsysErr != nil {
		return nil, fsysErr
	}
	f, err := fsys.Open("log", plan9.OREAD)
	if err != nil {
		return nil, err
	}
	return &LogReader{f: f}, nil
}

// Windows returns a list of the existing acme windows.
func Windows() ([]WinInfo, error) {
	fsysOnce.Do(mountAcme)
	if fsysErr != nil {
		return nil, fsysErr
	}
	index, err := fsys.Open("index", plan9.OREAD)
	if err != nil {
		return nil, err
	}
	defer index.Close()
	data, err := ioutil.ReadAll(index)
	if err != nil {
		return nil, err
	}
	var info []WinInfo
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Fields(line)
		if len(f) < 6 {
			continue
		}
		n, _ := strconv.Atoi(f[0])
		info = append(info, WinInfo{n, f[5]})
	}
	return info, nil
}

// Open connects to the existing window with the given id.
// If ctl is non-nil, Open uses it as the window's control file
// and takes ownership of it.
func Open(id int, ctl *client.Fid) (*Win, error) {
	fsysOnce.Do(mountAcme)
	if fsysErr != nil {
		return nil, fsysErr
	}
	if ctl == nil {
		var err error
		ctl, err = fsys.Open(fmt.Sprintf("%d/ctl", id), plan9.ORDWR)
		if err != nil {
			return nil, err
		}
	}

	w := new(Win)
	w.id = id
	w.ctl = ctl
	w.next = nil
	w.prev = last
	if last != nil {
		last.next = w
	} else {
		windows = w
	}
	last = w
	return w, nil
}

// Addr writes format, ... to the window's addr file.
func (w *Win) Addr(format string, args ...interface{}) error {
	return w.Fprintf("addr", format, args...)
}

// CloseFiles closes all the open files associated with the window w.
// (These file descriptors are cached across calls to Ctl, etc.)
func (w *Win) CloseFiles() {
	w.ctl.Close()
	w.ctl = nil

	w.body.Close()
	w.body = nil

	w.addr.Close()
	w.addr = nil

	w.tag.Close()
	w.tag = nil

	w.event.Close()
	w.event = nil
	w.ebuf = nil

	w.data.Close()
	w.data = nil

	w.xdata.Close()
	w.xdata = nil
}

// Ctl writes the command format, ... to the window's ctl file.
func (w *Win) Ctl(format string, args ...interface{}) error {
	return w.Fprintf("ctl", format+"\n", args...)
}

// Winctl deletes the window, writing `del' (or, if sure is true, `delete') to the ctl file.
func (w *Win) Del(sure bool) error {
	cmd := "del"
	if sure {
		cmd = "delete"
	}
	return w.Ctl(cmd)
}

// DeleteAll deletes all windows.
func DeleteAll() {
	for w := windows; w != nil; w = w.next {
		w.Ctl("delete")
	}
}

func (w *Win) OpenEvent() error {
	_, err := w.fid("event")
	return err
}

func (w *Win) fid(name string) (*client.Fid, error) {
	var f **client.Fid
	switch name {
	case "addr":
		f = &w.addr
	case "body":
		f = &w.body
	case "ctl":
		f = &w.ctl
	case "data":
		f = &w.data
	case "event":
		f = &w.event
	case "tag":
		f = &w.tag
	case "xdata":
		f = &w.xdata
	default:
		return nil, errors.New("unknown acme file: " + name)
	}
	if *f == nil {
		var err error
		*f, err = fsys.Open(fmt.Sprintf("%d/%s", w.id, name), plan9.ORDWR)
		if err != nil {
			return nil, err
		}
	}
	return *f, nil
}

// ReadAll
func (w *Win) ReadAll(file string) ([]byte, error) {
	f, err := w.fid(file)
	f.Seek(0, 0)
	if err != nil {
		return nil, err
	}
	return ioutil.ReadAll(f)
}

func (w *Win) Name(format string, args ...interface{}) error {
	return w.Ctl("name "+format, args...)
}

func (w *Win) Fprintf(file, format string, args ...interface{}) error {
	f, err := w.fid(file)
	if err != nil {
		return err
	}
	var buf bytes.Buffer
	fmt.Fprintf(&buf, format, args...)
	_, err = f.Write(buf.Bytes())
	return err
}

func (w *Win) Read(file string, b []byte) (n int, err error) {
	f, err := w.fid(file)
	if err != nil {
		return 0, err
	}
	return f.Read(b)
}

func (w *Win) ReadAddr() (q0, q1 int, err error) {
	f, err := w.fid("addr")
	if err != nil {
		return 0, 0, err
	}
	buf := make([]byte, 40)
	n, err := f.ReadAt(buf, 0)
	if err != nil {
		return 0, 0, err
	}
	a := strings.Fields(string(buf[0:n]))
	if len(a) < 2 {
		return 0, 0, errors.New("short read from acme addr")
	}
	q0, err0 := strconv.Atoi(a[0])
	q1, err1 := strconv.Atoi(a[1])
	if err0 != nil || err1 != nil {
		return 0, 0, errors.New("invalid read from acme addr")
	}
	return q0, q1, nil
}

func (w *Win) Seek(file string, offset int64, whence int) (int64, error) {
	f, err := w.fid(file)
	if err != nil {
		return 0, err
	}
	return f.Seek(offset, whence)
}

func (w *Win) Write(file string, b []byte) (n int, err error) {
	f, err := w.fid(file)
	if err != nil {
		return 0, nil
	}
	return f.Write(b)
}

const eventSize = 256

// An Event represents an event originating in a particular window.
// The fields correspond to the fields in acme's event messages.
// See http://swtch.com/plan9port/man/man4/acme.html for details.
type Event struct {
	// The two event characters, indicating origin and type of action
	C1, C2 rune

	// The character addresses of the action.
	// If the original event had an empty selection (OrigQ0=OrigQ1)
	// and was accompanied by an expansion (the 2 bit is set in Flag),
	// then Q0 and Q1 will indicate the expansion rather than the
	// original event.
	Q0, Q1 int

	// The Q0 and Q1 of the original event, even if it was expanded.
	// If there was no expansion, OrigQ0=Q0 and OrigQ1=Q1.
	OrigQ0, OrigQ1 int

	// The flag bits.
	Flag int

	// The number of bytes in the optional text.
	Nb int

	// The number of characters (UTF-8 sequences) in the optional text.
	Nr int

	// The optional text itself, encoded in UTF-8.
	Text []byte

	// The chorded argument, if present (the 8 bit is set in the flag).
	Arg []byte

	// The chorded location, if present (the 8 bit is set in the flag).
	Loc []byte
}

// ReadEvent reads the next event from the window's event file.
func (w *Win) ReadEvent() (e *Event, err error) {
	defer func() {
		if v := recover(); v != nil {
			e = nil
			err = errors.New("malformed acme event: " + v.(string))
		}
	}()

	if _, err = w.fid("event"); err != nil {
		return nil, err
	}

	e = new(Event)
	w.gete(e)
	e.OrigQ0 = e.Q0
	e.OrigQ1 = e.Q1

	// expansion
	if e.Flag&2 != 0 {
		e2 := new(Event)
		w.gete(e2)
		if e.Q0 == e.Q1 {
			e2.OrigQ0 = e.Q0
			e2.OrigQ1 = e.Q1
			e2.Flag = e.Flag
			e = e2
		}
	}

	// chorded argument
	if e.Flag&8 != 0 {
		e3 := new(Event)
		e4 := new(Event)
		w.gete(e3)
		w.gete(e4)
		e.Arg = e3.Text
		e.Loc = e4.Text
	}

	return e, nil
}

func (w *Win) gete(e *Event) {
	if w.ebuf == nil {
		w.ebuf = bufio.NewReader(w.event)
	}
	e.C1 = w.getec()
	e.C2 = w.getec()
	e.Q0 = w.geten()
	e.Q1 = w.geten()
	e.Flag = w.geten()
	e.Nr = w.geten()
	if e.Nr > eventSize {
		panic("event string too long")
	}
	r := make([]rune, e.Nr)
	for i := 0; i < e.Nr; i++ {
		r[i] = w.getec()
	}
	e.Text = []byte(string(r))
	if w.getec() != '\n' {
		panic("phase error")
	}
}

func (w *Win) getec() rune {
	c, _, err := w.ebuf.ReadRune()
	if err != nil {
		panic(err.Error())
	}
	return c
}

func (w *Win) geten() int {
	var (
		c rune
		n int
	)
	for {
		c = w.getec()
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c) - '0'
	}
	if c != ' ' {
		panic("event number syntax")
	}
	return n
}

// WriteEvent writes an event back to the window's event file,
// indicating to acme that the event should be handled internally.
func (w *Win) WriteEvent(e *Event) error {
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "%c%c%d %d \n", e.C1, e.C2, e.Q0, e.Q1)
	_, err := w.Write("event", buf.Bytes())
	return err
}

// EventChan returns a channel on which events can be read.
// The first call to EventChan allocates a channel and starts a
// new goroutine that loops calling ReadEvent and sending
// the result into the channel.  Subsequent calls return the
// same channel.  Clients should not call ReadEvent after calling
// EventChan.
func (w *Win) EventChan() <-chan *Event {
	if w.c == nil {
		w.c = make(chan *Event, 0)
		go w.eventReader()
	}
	return w.c
}

func (w *Win) eventReader() {
	for {
		e, err := w.ReadEvent()
		if err != nil {
			break
		}
		w.c <- e
	}
	close(w.c)
}
