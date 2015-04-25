// Package natty provides a Go language wrapper to the natty NAT traversal
// utility.  See https://github.com/getlantern/natty.
//
// See natty_test for an example of Natty in use, including debug logging
// showing the messages that are sent across the signaling channel.
package natty

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/byteexec"
	"github.com/getlantern/go-natty/natty/bin"
	"github.com/getlantern/golog"
)

const (
	UDP = Protocol("udp")
	TCP = Protocol("tcp")
)

var (
	log = golog.LoggerFor("natty")

	reallyHighTimeout = 100000 * time.Hour

	nattybe *byteexec.Exec
)

func init() {
	nattyBytes, err := bin.Asset("natty")
	if err != nil {
		panic(fmt.Errorf("Unable to read natty bytes: %s", err))
	}

	nattybe, err = byteexec.New(nattyBytes, "natty")
	if err != nil {
		panic(fmt.Errorf("Unable to construct byteexec for natty: %s", err))
	}
}

type Protocol string

// A FiveTuple is the result of a successful NAT traversal.
type FiveTuple struct {
	Proto  Protocol
	Local  string
	Remote string
}

// UDPAddrs returns a pair of UDPAddrs representing the Local and Remote
// addresses of this FiveTuple. If the FiveTuple's Proto is not UDP, this method
// returns an error.
func (ft *FiveTuple) UDPAddrs() (local *net.UDPAddr, remote *net.UDPAddr, err error) {
	if ft.Proto != UDP {
		err = fmt.Errorf("FiveTuple.Proto was not UDP!: %s", ft.Proto)
		return
	}
	local, err = net.ResolveUDPAddr("udp", ft.Local)
	if err != nil {
		err = fmt.Errorf("Unable to resolve local UDP address %s: %s", ft.Local, err)
		return
	}
	remote, err = net.ResolveUDPAddr("udp", ft.Remote)
	if err != nil {
		err = fmt.Errorf("Unable to resolve remote UDP address %s: %s", ft.Remote, err)
	}
	return
}

// Traversal represents a single NAT traversal using natty, whose result is
// available via the methods FiveTuple() and FiveTupleTimeout().
//
// Consumers should make sure to call Close() after finishing with this Natty
// in order to make sure the underlying natty process and associated resources
// are closed.
type Traversal struct {
	timeout            time.Duration   // how long to wait before terminating traversal
	traceOut           io.Writer       // target for output from natty's stderr
	cmd                *exec.Cmd       // the natty command
	stdin              io.WriteCloser  // pipe to natty's stdin
	stdout             io.ReadCloser   // pipe from natty's stdout
	stdoutbuf          *bufio.Reader   // buffered stdout
	stderr             io.ReadCloser   // pipe from natty's stderr
	msgInCh            chan string     // channel for messages inbound to this Natty
	msgOutCh           chan string     // channel for messages outbound from this Natty
	peerGotFiveTupleCh chan bool       // channel to signal once we know that our peer received their own FiveTuple
	fiveTupleCh        chan *FiveTuple // intermediary channel for the FiveTuple emitted by the natty command
	errCh              chan error      // intermediary channel for any error encountered while running natty
	fiveTupleOutCh     chan *FiveTuple // channel for FiveTuple output
	errOutCh           chan error      // channel for error output
	fiveTupleOut       *FiveTuple      // the output FiveTuple
	errOut             error           // the output error
	outMutex           sync.Mutex      // mutex for synchronizing access to output variables
	iowg               sync.WaitGroup  // WaitGroup to wait for stdout and stderr processing to finish
}

// Offer starts a Traversal as an Offerer, meaning that it will make an offer to
// initiate an ICE session. Call FiveTuple() to get the FiveTuple resulting from
// Traversal. If timeout is hit, the traversal will stop and FiveTuple() will
// return an error. A timeout of 0 means that the Traversal will never time out.
func Offer(timeout time.Duration) *Traversal {
	log.Trace("Offering")
	t := &Traversal{
		timeout:  timeout,
		traceOut: log.TraceOut(),
	}
	t.run([]string{"-offer"})
	return t
}

// Answer starts a Traversal as an Answerer, meaning that it will accept offers
// to initiate an ICE session. Call FiveTuple() to get the FiveTuple resulting from
// Traversal. If timeout is hit, the traversal will stop and FiveTuple() will
// return an error. A timeout of 0 means that the Traversal will never time out.
func Answer(timeout time.Duration) *Traversal {
	log.Trace("Answering")
	t := &Traversal{
		timeout:  timeout,
		traceOut: log.TraceOut(),
	}
	t.run([]string{})
	return t
}

// MsgIn is used to pass this Traversal a message from the peer t. This method
// is buffered and will typically not block.
func (t *Traversal) MsgIn(msg string) {
	log.Tracef("Got message: %s", msg)
	t.msgInCh <- msg
}

// NextMsgOut gets the next message to pass to the peer.  If done is true, there
// are no more messages to be read, and the currently returned message should be
// ignored.
func (t *Traversal) NextMsgOut() (msg string, done bool) {
	m, ok := <-t.msgOutCh
	log.Tracef("Returning out message: %s", m)
	return m, !ok
}

// FiveTuple gets the FiveTuple from the Traversal, blocking until such is
// available or the configured timeout is hit.
func (t *Traversal) FiveTuple() (*FiveTuple, error) {
	log.Trace("Getting FiveTuple")
	t.outMutex.Lock()
	defer t.outMutex.Unlock()

	if t.fiveTupleOut != nil || t.errOut != nil {
		log.Trace("Returning existing result")
	} else {
		log.Trace("We don't have a result yet, wait for one")
		select {
		case ft := <-t.fiveTupleOutCh:
			log.Tracef("FiveTuple is: %s", ft)
			t.fiveTupleOut = ft
		case err := <-t.errOutCh:
			log.Tracef("Error is: %s", err)
			t.errOut = err
		}
	}

	log.Tracef("FiveTuple returns %s: %s", t.fiveTupleOut, t.errOut)
	return t.fiveTupleOut, t.errOut
}

// Close closes this Traversal, terminating any outstanding natty process by
// sending SIGKILL. Close blocks until the natty process has terminated, at
// which point any ports that it bound should be available for use.
func (t *Traversal) Close() error {
	if t.cmd == nil || t.cmd.Process == nil {
		return nil
	} else {
		log.Trace("Killing natty process")
		err := t.cmd.Process.Kill()
		if err != nil {
			return fmt.Errorf("Unable to kill natty process: %s", err)
		}
		log.Trace("Waiting for reading from pipes to finish")
		t.iowg.Wait()
		log.Trace("Waiting for natty process to die")
		err = t.cmd.Wait()
		log.Trace("natty process is dead")
		return err
	}
}

// run runs the natty command to obtain a FiveTuple. The actual running of
// natty happens on a goroutine so that run itself doesn't block.
func (t *Traversal) run(params []string) {
	t.msgInCh = make(chan string, 100)
	t.msgOutCh = make(chan string, 100)

	// Note - these channels are buffered in order to prevent deadlocks
	// The bufferDepth just needs to be at least as large as the total number of
	// goroutines created during a single traversal (which is about 4).
	bufferDepth := 10
	t.peerGotFiveTupleCh = make(chan bool, bufferDepth)
	t.fiveTupleCh = make(chan *FiveTuple, bufferDepth)
	t.errCh = make(chan error, bufferDepth)
	t.fiveTupleOutCh = make(chan *FiveTuple, bufferDepth)
	t.errOutCh = make(chan error, bufferDepth)

	err := t.initCommand(params)

	go func() {
		if err != nil {
			t.errOutCh <- err
			return
		}

		ft, err := t.doRun(params)
		log.Trace("doRun is finished, inform client of the FiveTuple or error")
		if err != nil {
			log.Tracef("Returning error: %s", err)
			t.errOutCh <- err
			log.Tracef("Returned error: %s", err)
		} else {
			log.Tracef("Returning FiveTuple: %s", ft)
			t.fiveTupleOutCh <- ft
		}
	}()
}

// doRun does the running, including resource cleanup.  doRun blocks until
// Close() has finished, meaning that natty is no longer running and whatever
// port it returned in the FiveTuple can now be used for other things.
func (t *Traversal) doRun(params []string) (*FiveTuple, error) {
	defer t.Close()

	t.iowg.Add(2)
	go t.processStdout()
	go t.processStderr()

	// Start the natty command
	t.errCh <- t.cmd.Start()

	go t.processIncoming()

	return t.waitForFiveTuple()
}

// initCommand sets up the natty command
func (t *Traversal) initCommand(params []string) (err error) {
	if log.IsTraceEnabled() {
		log.Trace("Telling natty to log debug output")
		params = append(params, "-debug")
	}

	t.cmd = nattybe.Command(params...)
	t.stdin, err = t.cmd.StdinPipe()
	if err != nil {
		return err
	}
	t.stdout, err = t.cmd.StdoutPipe()
	if err != nil {
		return err
	}
	t.stderr, err = t.cmd.StderrPipe()
	if err != nil {
		return err
	}

	t.stdoutbuf = bufio.NewReader(t.stdout)

	return nil
}

// processStdout reads the output from natty and sends it to the msgOutCh. If
// it finds a FiveTuple, it records that.
func (t *Traversal) processStdout() {
	defer t.iowg.Done()

	for {
		// Read next message from natty
		msg, err := t.stdoutbuf.ReadString('\n')
		if err != nil {
			t.errCh <- err
			return
		}

		log.Trace("Request send of message to peer")
		t.msgOutCh <- msg

		if IsFiveTuple(msg) {
			log.Trace("We got a FiveTuple!")
			fiveTuple := &FiveTuple{}
			err = json.Unmarshal([]byte(msg), fiveTuple)
			if err != nil {
				t.errCh <- err
				return
			}
			t.fiveTupleCh <- fiveTuple
		} else if IsError(msg) {
			log.Trace("We got an error")
			msgmap := make(map[string]string)
			err = json.Unmarshal([]byte(msg), msgmap)
			if err == nil {
				err = fmt.Errorf("Error reported by natty: %s", msgmap["message"])
			}
			t.errCh <- err
			return
		}
	}
}

// processStderr copies the output from natty's stderr to the configured
// traceOut
func (t *Traversal) processStderr() {
	defer t.iowg.Done()

	_, err := io.Copy(t.traceOut, t.stderr)
	t.errCh <- err
}

func (t *Traversal) processIncoming() {
	for {
		msg := <-t.msgInCh
		log.Tracef("Got incoming message: %s", msg)

		if IsFiveTuple(msg) {
			log.Trace("Incoming message was a FiveTuple!")
			t.peerGotFiveTupleCh <- true
			continue
		}

		log.Trace("Forward message to natty process")
		_, err := t.stdin.Write([]byte(msg))
		if err == nil {
			_, err = t.stdin.Write([]byte("\n"))
		}
		if err != nil {
			log.Tracef("Unable to forward message to natty process: %s: %s", msg, err)
			t.errCh <- err
		} else {
			log.Tracef("Forwarded message to natty process: %s", msg)
		}
	}
}

func (t *Traversal) waitForFiveTuple() (*FiveTuple, error) {
	timeout := t.timeout
	if timeout == 0 {
		timeout = reallyHighTimeout
	}

	timeoutCh := time.After(timeout)

	for {
		select {
		case result := <-t.fiveTupleCh:
			// Wait for peer to get FiveTuple before returning.  If we didn't do
			// this, our natty instance might stop running before the peer
			// finishes its work to get its own FiveTuple.
			log.Trace("Got our own FiveTuple, waiting for peer to get FiveTuple")
			<-t.peerGotFiveTupleCh
			log.Trace("Peer got FiveTuple!")
			return result, nil
		case err := <-t.errCh:
			if err != nil && err != io.EOF {
				return nil, err
			}
		case <-timeoutCh:
			msg := "Timed out waiting for five-tuple"
			log.Trace(msg)
			return nil, fmt.Errorf(msg)
		}
	}
}

func IsFiveTuple(msg string) bool {
	return strings.Contains(msg, "\"type\":\"5-tuple\"")
}

func IsError(msg string) bool {
	return strings.Contains(msg, "\"type\":\"error\"")
}
