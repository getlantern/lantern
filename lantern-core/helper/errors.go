package helper

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
)

// Error is an operation's failure, reported to the UI as {"error": Code}.
// Codes are fixed strings and safe to log; nothing else about a failure is.
type Error struct{ Code string }

func (e *Error) Error() string { return "helper: " + e.Code }

const (
	CodeLocked          = "locked"
	CodeDisabled        = "disabled"
	CodeNotFound        = "not_found"
	CodeAlreadyClaimed  = "already_claimed"
	CodeNoPendingClaim  = "no_pending_claim"
	CodeTooManyInvites  = "too_many_invites"
	CodeTooManyPairings = "too_many_pairings"
	CodeBadLink         = "bad_link"
	CodeBadName         = "bad_name"
	CodeOwnInvite       = "own_invite"
	CodeUnavailable     = "unavailable"
	CodeInternal        = "internal"
)

func errCode(code string) *Error { return &Error{Code: code} }

// ErrorJSON is the bridge's answer for err: {"error": code}.
func ErrorJSON(err error) string {
	code := CodeInternal
	var he *Error
	if errors.As(err, &he) {
		code = he.Code
	}
	b, _ := json.Marshal(map[string]string{"error": code})
	return string(b)
}

// statusError maps a HelperService status to a code. The gate's 404 for a
// client the flag is off for reads "404 page not found"; other 404s are a
// missing invite or pairing.
func statusError(op string, status int, errText string) *Error {
	switch {
	case status == http.StatusNotFound && strings.Contains(errText, "page not found"):
		return errCode(CodeDisabled)
	case status == http.StatusNotFound:
		return errCode(CodeNotFound)
	case status == http.StatusConflict && op == "invites/claim":
		return errCode(CodeAlreadyClaimed)
	case status == http.StatusConflict && op == "invites/decide":
		return errCode(CodeNoPendingClaim)
	case status == http.StatusTooManyRequests && strings.Contains(errText, "too many requests"):
		// The flag-free gate's rate limit (lantern-cloud Task 1): retry later.
		return errCode(CodeUnavailable)
	case status == http.StatusTooManyRequests && strings.Contains(errText, "pairings"):
		return errCode(CodeTooManyPairings)
	case status == http.StatusTooManyRequests:
		return errCode(CodeTooManyInvites)
	case status >= 500:
		return errCode(CodeUnavailable)
	}
	return errCode(CodeInternal)
}
