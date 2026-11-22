package lanterncore

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/radiance/ipc"
)

func withUsageBusyRetries(t *testing.T, d ...time.Duration) {
	t.Helper()
	old := usageBusyRetries
	usageBusyRetries = d
	t.Cleanup(func() { usageBusyRetries = old })
}

func TestRetryUsageBusy(t *testing.T) {
	busy := &ipc.Error{Status: http.StatusServiceUnavailable, Message: "usage stats are busy"}
	other := &ipc.Error{Status: http.StatusInternalServerError, Message: "boom"}

	for _, tc := range []struct {
		name      string
		results   []error
		wantCalls int
		wantErr   error
	}{
		{"succeeds first time", []error{nil}, 1, nil},
		{"busy then succeeds", []error{busy, nil}, 2, nil},
		{"busy until out of retries", []error{busy, busy, busy, nil}, 3, busy},
		{"other status is not retried", []error{other, nil}, 1, other},
		{"plain error is not retried", []error{errors.New("dial"), nil}, 1, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			withUsageBusyRetries(t, time.Millisecond, time.Millisecond)
			calls := 0
			err := retryUsageBusy(context.Background(), func() error {
				err := tc.results[calls]
				calls++
				return err
			})
			if calls != tc.wantCalls {
				t.Fatalf("calls = %d, want %d", calls, tc.wantCalls)
			}
			if tc.wantErr != nil && err != tc.wantErr {
				t.Fatalf("err = %v, want %v", err, tc.wantErr)
			}
			if tc.results[tc.wantCalls-1] == nil && err != nil {
				t.Fatalf("err = %v, want nil", err)
			}
			if tc.results[tc.wantCalls-1] != nil && err == nil {
				t.Fatal("err = nil, want the last call's error")
			}
		})
	}
}

func TestRetryUsageBusyStopsWhenContextDone(t *testing.T) {
	withUsageBusyRetries(t, time.Hour)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	calls := 0
	err := retryUsageBusy(ctx, func() error {
		calls++
		return &ipc.Error{Status: http.StatusServiceUnavailable}
	})
	if calls != 1 || err == nil {
		t.Fatalf("calls = %d, err = %v; want 1 call and its error", calls, err)
	}
}
