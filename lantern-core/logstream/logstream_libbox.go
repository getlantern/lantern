package logstream

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/sagernet/sing-box/experimental/libbox"
)

type provider interface {
	Start(ctx context.Context, h Handler) error
	Stop() error
}

type libboxProvider struct {
	opts   Options
	client *libbox.CommandClient
	mu     sync.Mutex
}

func newLibboxProvider(opts Options) (provider, error) {
	return &libboxProvider{opts: opts}, nil
}

type lbHandler struct{ h Handler }

func (l *lbHandler) Disconnected(message string)                                            {}
func (l *lbHandler) InitializeClashMode(modeList libbox.StringIterator, currentMode string) {}
func (l *lbHandler) UpdateClashMode(newMode string)                                         {}
func (l *lbHandler) WriteConnections(message *libbox.Connections)                           {}
func (l *lbHandler) WriteGroups(message libbox.OutboundGroupIterator)                       {}
func (l *lbHandler) WriteStatus(message *libbox.StatusMessage)                              {}
func (l *lbHandler) Connected()                                                             {}

func (l *lbHandler) WriteLogs(it libbox.StringIterator) {
	var lines []string
	for it.HasNext() {
		lines = append(lines, it.Next())
	}
	if len(lines) > 0 {
		l.h(strings.Join(lines, "\n"))
	}
}

func (l *lbHandler) ClearLogs() { l.h("") }

func (p *libboxProvider) Start(ctx context.Context, h Handler) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.client != nil {
		return nil
	}

	handler := &lbHandler{h: h}
	p.client = libbox.NewCommandClient(handler, &libbox.CommandClientOptions{
		Command:        libbox.CommandLog,
		StatusInterval: int64(p.opts.Interval / time.Millisecond),
	})
	if err := p.client.Connect(); err != nil {
		p.client = nil
		return err
	}

	go func() {
		<-ctx.Done()
		_ = p.Stop()
	}()
	return nil
}

func (p *libboxProvider) Stop() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.client == nil {
		return nil
	}
	err := p.client.Disconnect()
	p.client = nil
	return err
}
