package utils

import (
	"errors"
	"fmt"
	"testing"
)

var errSentinel = errors.New("sentinel")

// TestRunOffCgoStackPreservesErrorIdentity pins the property that cost a
// CI failure once already: sanitizing the message for the objc bridge must not
// cost callers errors.Is. Rebuilding the error with errors.New leaves the text
// identical, so the breakage is invisible in logs and only shows up as a
// sentinel comparison that silently stops matching.
func TestRunOffCgoStackPreservesErrorIdentity(t *testing.T) {
	tests := []struct {
		name string
		err  error
	}{
		{"bare sentinel", errSentinel},
		{"wrapped sentinel", fmt.Errorf("context: %w", errSentinel)},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, got := RunOffCgoStack(func() (struct{}, error) { return struct{}{}, tc.err })
			if !errors.Is(got, errSentinel) {
				t.Fatalf("errors.Is lost the sentinel: got %v (%T)", got, got)
			}
			if got.Error() != tc.err.Error() {
				t.Errorf("message changed: got %q, want %q", got.Error(), tc.err.Error())
			}
		})
	}
}

// invalidUTF8Error reproduces the shape that aborts the app: the bridge calls
// NSString initWithBytes:encoding:UTF8 on these bytes, gets nil back, and then
// inserts nil into a dictionary literal.
type invalidUTF8Error struct{ msg string }

func (e *invalidUTF8Error) Error() string { return e.msg }

func TestRunOffCgoStackSanitizesUnsafeMessages(t *testing.T) {
	tests := []struct {
		name string
		in   error
		want string
	}{
		// ToValidUTF8 collapses each run of invalid bytes into one replacement,
		// so the two bad bytes here yield a single "?".
		{"invalid utf-8 is replaced", &invalidUTF8Error{msg: "bad\xff\xfebytes"}, "bad?bytes"},
		{"empty message gets a stand-in", &invalidUTF8Error{msg: ""}, "unknown error"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, got := RunOffCgoStack(func() (struct{}, error) { return struct{}{}, tc.in })
			if got.Error() != tc.want {
				t.Errorf("message: got %q, want %q", got.Error(), tc.want)
			}
			// Sanitizing the text is not a licence to drop the original.
			if !errors.Is(got, tc.in) {
				t.Errorf("sanitized error no longer unwraps to the original")
			}
		})
	}
}

// mutatingError answers differently on each call, the way an error formatting a
// buffer another goroutine is still appending to would. The bridge calls
// Error() itself when it builds NSLocalizedDescriptionKey, so validating a
// message and handing back the callee's error would let the second answer —
// the one that actually gets marshalled — be anything at all.
type mutatingError struct{ calls int }

func (e *mutatingError) Error() string {
	e.calls++
	if e.calls == 1 {
		return "fine"
	}
	return "bad\xffbytes"
}

func TestRunOffCgoStackFreezesTheMessage(t *testing.T) {
	in := &mutatingError{}
	_, got := RunOffCgoStack(func() (struct{}, error) { return struct{}{}, in })
	first := got.Error()
	if first != "fine" {
		t.Fatalf("first read: got %q, want %q", first, "fine")
	}
	if second := got.Error(); second != first {
		t.Errorf("message not frozen: bridge would marshal %q after seeing %q", second, first)
	}
}

// A nil *typedNilError inside a non-nil error interface derefs on Error().
type typedNilError struct{ msg string }

func (e *typedNilError) Error() string { return e.msg }

func TestRunOffCgoStackSurvivesTypedNilError(t *testing.T) {
	var typed *typedNilError
	_, got := RunOffCgoStack(func() (struct{}, error) { return struct{}{}, typed })
	if got == nil {
		t.Fatal("a non-nil error interface must not come back nil")
	}
	if got.Error() == "" {
		t.Error("the bridge needs a non-empty message even for this shape")
	}
	// Recovering from the panic must not quietly cost the caller the cause;
	// an error that panics while formatting can still be the one they are
	// testing for.
	if !errors.Is(got, error(typed)) {
		t.Error("the recovered error no longer unwraps to the original")
	}
	var as *typedNilError
	if !errors.As(got, &as) {
		t.Error("errors.As cannot reach the original through the recovery path")
	}
}

func TestRunOffCgoStackNilErrorStaysNil(t *testing.T) {
	if _, err := RunOffCgoStack(func() (int, error) { return 7, nil }); err != nil {
		t.Fatalf("nil error became %v", err)
	}
}

func TestRunOffCgoStackRecoversPanic(t *testing.T) {
	_, err := RunOffCgoStack(func() (struct{}, error) { panic("boom") })
	if err == nil {
		t.Fatal("a panic must surface as an error rather than blocking the caller")
	}
}
