package logstream

import (
	"context"
	"errors"
	"time"
)

var ErrNoBackend = errors.New("backend unavailable")

type Options struct {
	DataDir      string
	LogFile      string
	Interval     time.Duration
	InitialLines int
}

type Handler func(batch string)

type Stream interface {
	Start(ctx context.Context, h Handler) error
	Stop() error
}

func New(opts Options) Stream { return &stream{opts: opts} }

type stream struct {
	opts Options
	p    provider
}

func (s *stream) Start(ctx context.Context, h Handler) error {
	if p, err := newLibboxProvider(s.opts); err == nil && p != nil {
		if err := p.Start(ctx, h); err == nil {
			s.p = p
			return nil
		}
	}

	if s.opts.LogFile != "" {
		if p, err := newTailProvider(s.opts); err == nil {
			if err := p.Start(ctx, h); err == nil {
				s.p = p
				return nil
			}
			return err
		} else {
			return err
		}
	}
	return ErrNoBackend
}

func (s *stream) Stop() error {
	if s.p == nil {
		return nil
	}
	return s.p.Stop()
}
