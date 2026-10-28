package helper

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlantern/broflake/common/helperinvite"
)

var testKey = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32))

func newTestEngine(t *testing.T, cloud *fakeCloud, device, dir string) *Engine {
	t.Helper()
	e := NewEngine(dir, cloud.relay(device), nil)
	call(t, e, "unlock", map[string]any{"key": testKey})
	return e
}

func call(t *testing.T, e *Engine, op string, args map[string]any) map[string]any {
	t.Helper()
	out, err := e.Call(context.Background(), op, mustJSON(args))
	require.NoError(t, err, op)
	var m map[string]any
	require.NoError(t, json.Unmarshal(out, &m))
	return m
}

func callErr(t *testing.T, e *Engine, op string, args map[string]any) string {
	t.Helper()
	_, err := e.Call(context.Background(), op, mustJSON(args))
	var he *Error
	require.True(t, errors.As(err, &he), "%s: want *Error, got %v", op, err)
	return he.Code
}

func list(m map[string]any, key string) []map[string]any {
	raw, _ := m[key].([]any)
	out := make([]map[string]any, 0, len(raw))
	for _, r := range raw {
		out = append(out, r.(map[string]any))
	}
	return out
}

func TestInviteClaimApproveEnd(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara-device", t.TempDir())
	aliDir := t.TempDir()
	ali := newTestEngine(t, cloud, "ali-device", aliDir)

	inv := call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	link := inv["link"].(string)
	require.True(t, strings.HasPrefix(link, helperinvite.LinkPrefix))
	pending := list(call(t, sara, "view", nil), "invites")
	require.Len(t, pending, 1)
	assert.Equal(t, "pending", pending[0]["state"])
	assert.Equal(t, link, pending[0]["link"], "an unclaimed invite can be re-shared")

	cl := call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	code := cl["code"].(string)
	assert.Regexp(t, `^[0-9]{4}$`, code)
	assert.Len(t, list(call(t, ali, "view", nil), "claims"), 1)

	sv := call(t, sara, "refresh", nil)
	claimed := list(sv, "invites")
	require.Len(t, claimed, 1)
	assert.Equal(t, "claimed", claimed[0]["state"])
	assert.Equal(t, code, claimed[0]["code"], "both sides compute the same code")
	assert.Equal(t, "Ali", claimed[0]["volunteer_name"])
	assert.Nil(t, claimed[0]["link"], "a claimed invite no longer offers its link")

	sv = call(t, sara, "decide", map[string]any{"invite_id": claimed[0]["id"], "approve": true})
	assert.Empty(t, list(sv, "invites"), "a decided invite is forgotten, with its secret")
	helpers := list(sv, "helpers")
	require.Len(t, helpers, 1)
	assert.Equal(t, "Ali", helpers[0]["name"])
	assert.Nil(t, helpers[0]["online"])

	cloud.online["ali-device"] = true
	helpers = list(call(t, sara, "refresh", nil), "helpers")
	assert.Equal(t, true, helpers[0]["online"])

	av := call(t, ali, "refresh", nil)
	helping := list(av, "helping")
	require.Len(t, helping, 1)
	assert.Equal(t, "Sara", helping[0]["name"], "the inviter's name opens with the pending claim's key")
	assert.Equal(t, true, av["new_helping"])
	assert.Empty(t, list(av, "claims"))
	assert.Equal(t, false, call(t, ali, "refresh", nil)["new_helping"], "only the first refresh reports it")

	again := newTestEngine(t, cloud, "ali-device", aliDir)
	assert.Equal(t, "Sara", list(call(t, again, "view", nil), "helping")[0]["name"], "names survive a restart")

	call(t, sara, "end_pairing", map[string]any{"pairing_id": helpers[0]["pairing_id"]})
	assert.Empty(t, list(call(t, sara, "view", nil), "helpers"))
	assert.Empty(t, list(call(t, ali, "refresh", nil), "helping"), "the other side learns at its next refresh")
}

func TestASecondClaimIsAlreadyClaimed(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	call(t, newTestEngine(t, cloud, "eve", t.TempDir()), "claim", map[string]any{"link": link, "name": "Eve"})
	assert.Equal(t, CodeAlreadyClaimed,
		callErr(t, newTestEngine(t, cloud, "ali", t.TempDir()), "claim", map[string]any{"link": link, "name": "Ali"}))
}

func TestRejectBurnsTheInvite(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	call(t, newTestEngine(t, cloud, "eve", t.TempDir()), "claim", map[string]any{"link": link, "name": "Eve"})
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	sv := call(t, sara, "decide", map[string]any{"invite_id": id, "approve": false})
	assert.Empty(t, list(sv, "invites"))
	assert.Empty(t, list(sv, "helpers"))
	assert.Equal(t, CodeAlreadyClaimed,
		callErr(t, newTestEngine(t, cloud, "ali", t.TempDir()), "claim", map[string]any{"link": link, "name": "Ali"}))
}

func TestClaimRefusals(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	assert.Equal(t, CodeOwnInvite, callErr(t, sara, "claim", map[string]any{"link": link, "name": "Sara"}))
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	assert.Equal(t, CodeBadLink, callErr(t, ali, "claim", map[string]any{"link": "https://evil.example/#x", "name": "Ali"}))
	assert.Equal(t, CodeBadName, callErr(t, ali, "claim", map[string]any{"link": link, "name": "  "}))
	assert.Equal(t, CodeBadName, callErr(t, sara, "create_invite", map[string]any{"name": ""}))
	first := call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	second := call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	assert.Equal(t, first, second, "claiming the same link again returns the same claim")
}

func TestStatusErrors(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	cloud.disabled = true
	assert.Equal(t, CodeDisabled, callErr(t, sara, "create_invite", map[string]any{"name": "Sara"}))
	cloud.disabled, cloud.down = false, true
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "refresh", nil))
	fresh := NewEngine(t.TempDir(), cloud.relay("x"), nil)
	assert.Equal(t, CodeLocked, callErr(t, fresh, "view", nil))
	assert.JSONEq(t, `{"error":"locked"}`, ErrorJSON(&Error{Code: CodeLocked}))
	assert.JSONEq(t, `{"error":"internal"}`, ErrorJSON(errors.New("boom")))
}

func TestStateIsSealed(t *testing.T) {
	cloud := newFakeCloud()
	dir := t.TempDir()
	sara := newTestEngine(t, cloud, "sara", dir)
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	secret := strings.TrimPrefix(link, helperinvite.LinkPrefix)
	data, err := os.ReadFile(filepath.Join(dir, stateFile))
	require.NoError(t, err)
	assert.NotContains(t, string(data), "Sara")
	assert.NotContains(t, string(data), secret)
	info, err := os.Stat(filepath.Join(dir, stateFile))
	require.NoError(t, err)
	if os.PathSeparator == '/' {
		assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
	}

	other := NewEngine(dir, cloud.relay("sara"), nil)
	out := call(t, other, "unlock", map[string]any{"key": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))})
	assert.Empty(t, list(out, "invites"), "another key reads nothing")
	assert.Equal(t, true, out["keystore_reset"], "and says so rather than silently starting over")
	assert.FileExists(t, filepath.Join(dir, stateFile+".bak"), "the unreadable state is kept")
	assert.Nil(t, call(t, other, "view", nil)["keystore_reset"], "reported once, at unlock")
}

// TestVolunteerAbroadWithoutTheFlag covers a volunteer that lantern-cloud
// gates by its claim or pairing (Task 1): after its claim is rejected, and
// after its last pairing ends, the gate answers 404, and the engine must
// read that as "nothing", not as an error that strands the claim or row.
func TestVolunteerAbroadWithoutTheFlag(t *testing.T) {
	cloud := newFakeCloud()
	cloud.flagOff["ali"] = true
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	ali := newTestEngine(t, cloud, "ali", t.TempDir())

	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	assert.Len(t, list(call(t, ali, "refresh", nil), "claims"), 1, "a live claim passes the gate")
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	call(t, sara, "decide", map[string]any{"invite_id": id, "approve": false})
	assert.Empty(t, list(call(t, ali, "refresh", nil), "claims"), "the rejected claim is dropped, not left waiting")

	link = call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	id = list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	call(t, sara, "decide", map[string]any{"invite_id": id, "approve": true})
	require.Len(t, list(call(t, ali, "refresh", nil), "helping"), 1)
	pid := list(call(t, sara, "view", nil), "helpers")[0]["pairing_id"]
	call(t, sara, "end_pairing", map[string]any{"pairing_id": pid})
	assert.Empty(t, list(call(t, ali, "refresh", nil), "helping"), "the ended pairing's row is removed")
}

// TestCancelledInviteRejectsALaterClaim covers the tombstone: a cancelled,
// unclaimed invite is hidden, and a claim that arrives later is rejected at
// the next refresh instead of waiting for an approval that cannot come.
func TestCancelledInviteRejectsALaterClaim(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	inv := call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	sv := call(t, sara, "forget_invite", map[string]any{"invite_id": inv["invite_id"]})
	assert.Empty(t, list(sv, "invites"), "a cancelled invite is hidden")
	call(t, newTestEngine(t, cloud, "eve", t.TempDir()), "claim", map[string]any{"link": inv["link"], "name": "Eve"})
	assert.Empty(t, list(call(t, sara, "refresh", nil), "invites"))
	assert.Empty(t, list(call(t, sara, "view", nil), "helpers"))
	cloud.mu.Lock()
	defer cloud.mu.Unlock()
	for _, fi := range cloud.invites {
		assert.Equal(t, "rejected", fi.state, "the late claim was rejected")
	}
}

// TestEachInviteKeepsItsOwnName checks that approval seals the name given for
// that invite, not whichever name was typed last.
func TestEachInviteKeepsItsOwnName(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	first := call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	call(t, sara, "create_invite", map[string]any{"name": "S. from work"})
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	call(t, ali, "claim", map[string]any{"link": first["link"], "name": "Ali"})
	for _, iv := range list(call(t, sara, "refresh", nil), "invites") {
		if iv["state"] == "claimed" {
			call(t, sara, "decide", map[string]any{"invite_id": iv["id"], "approve": true})
		}
	}
	assert.Equal(t, "Sara", list(call(t, ali, "refresh", nil), "helping")[0]["name"])
}

func TestExpiredInvitesAndClaimsArePruned(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	later := time.Now().Add(InviteTTL + time.Hour)
	sara.now = func() time.Time { return later }
	ali.now = func() time.Time { return later }
	assert.Empty(t, list(call(t, sara, "refresh", nil), "invites"))
	assert.Empty(t, list(call(t, ali, "refresh", nil), "claims"))
}

func TestEndAllHelpers(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	for _, v := range []string{"ali", "bo"} {
		link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
		call(t, newTestEngine(t, cloud, v, t.TempDir()), "claim", map[string]any{"link": link, "name": v})
		inv := list(call(t, sara, "refresh", nil), "invites")
		call(t, sara, "decide", map[string]any{"invite_id": inv[0]["id"], "approve": true})
	}
	call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	require.Len(t, list(call(t, sara, "view", nil), "helpers"), 2)
	sv := call(t, sara, "end_all_helpers", nil)
	assert.Empty(t, list(sv, "helpers"))
	assert.Empty(t, list(sv, "invites"))
	assert.Empty(t, cloud.pairings)
}

func TestRefreshReadsActivity(t *testing.T) {
	cloud := newFakeCloud()
	e := NewEngine(t.TempDir(), cloud.relay("ali"), func(context.Context) (Activity, error) {
		return Activity{Day: "2026-10-23", ActiveSeconds: 3600, RelayedBytes: 42}, nil
	})
	call(t, e, "unlock", map[string]any{"key": testKey})
	act := call(t, e, "refresh", nil)["activity"].(map[string]any)
	assert.Equal(t, "2026-10-23", act["day"])
	assert.Equal(t, float64(3600), act["active_seconds"])
	assert.Equal(t, float64(42), act["relayed_bytes"])
}

// TestMalformedVolunteerKeyIsUnavailable covers a server answer whose volunteer
// key is not 32 bytes: MatchingCode returns "" and NewApproval ErrKey. Both
// are a malformed answer from lantern-cloud, never a claimed invite with an
// empty code, and never bad_name.
func TestMalformedVolunteerKeyIsUnavailable(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	call(t, newTestEngine(t, cloud, "ali", t.TempDir()), "claim", map[string]any{"link": link, "name": "Ali"})
	cloud.mu.Lock()
	for _, fi := range cloud.invites {
		fi.volunteerPub = fi.volunteerPub[:16]
	}
	cloud.mu.Unlock()
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "refresh", nil))
	iv := list(call(t, sara, "view", nil), "invites")
	require.Len(t, iv, 1)
	assert.Equal(t, "pending", iv[0]["state"], "not shown as claimed")
	assert.Nil(t, iv[0]["code"])

	sara.st.Invites[0].State = "claimed"
	sara.st.Invites[0].VolunteerPub = bytes.Repeat([]byte{7}, 16)
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "decide",
		map[string]any{"invite_id": sara.st.Invites[0].ID, "approve": true}))
	assert.Len(t, list(call(t, sara, "view", nil), "invites"), 1, "the invite is kept")
	assert.Empty(t, list(call(t, sara, "view", nil), "helpers"))
}

// pair makes sara's invite, claimed by device "ali" as Ali and approved.
func pair(t *testing.T, cloud *fakeCloud, sara *Engine, aliDir string) *Engine {
	t.Helper()
	ali := newTestEngine(t, cloud, "ali", aliDir)
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	call(t, sara, "decide", map[string]any{"invite_id": id, "approve": true})
	return ali
}

// TestInviterKeepsHelpersWhenTheGateSaysDisabled: a 404 from the gate to an
// inviter with no open invites drops only the volunteer side.
func TestInviterKeepsHelpersWhenTheGateSaysDisabled(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	pair(t, cloud, sara, t.TempDir())
	cloud.flagOff["sara"] = true
	helpers := list(call(t, sara, "refresh", nil), "helpers")
	require.Len(t, helpers, 1, "the helper row is kept")
	assert.Equal(t, "Ali", helpers[0]["name"])
	cloud.flagOff["sara"] = false
	call(t, sara, "end_pairing", map[string]any{"pairing_id": helpers[0]["pairing_id"]})
	assert.Empty(t, cloud.pairings)
}

func TestClaimAnswerLostThenRetried(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	cloud.loseAnswer["invites/claim"] = true
	assert.Equal(t, CodeUnavailable, callErr(t, ali, "claim", map[string]any{"link": link, "name": "Ali"}))
	cl := call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	assert.Equal(t, cl, call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"}))
	require.Len(t, cloud.bodies["invites/claim"], 2, "the confirmed claim is not sent again")
	assert.Equal(t, cloud.bodies["invites/claim"][0], cloud.bodies["invites/claim"][1], "the retry is the same request, same seed")
	inv := list(call(t, sara, "refresh", nil), "invites")[0]
	assert.Equal(t, cl["code"], inv["code"])
	call(t, sara, "decide", map[string]any{"invite_id": inv["id"], "approve": true})
	assert.Equal(t, "Sara", list(call(t, ali, "refresh", nil), "helping")[0]["name"])
}

func TestClaimNeverSentThenRetried(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	aliDir := t.TempDir()
	ali := newTestEngine(t, cloud, "ali", aliDir)
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	cloud.down = true
	assert.Equal(t, CodeUnavailable, callErr(t, ali, "claim", map[string]any{"link": link, "name": "Ali"}))
	cloud.down = false
	ali = newTestEngine(t, cloud, "ali", aliDir) // the provisional claim survives a restart
	cl := call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	assert.Equal(t, cloud.bodies["invites/claim"][0], cloud.bodies["invites/claim"][1])
	assert.Equal(t, cl["code"], list(call(t, sara, "refresh", nil), "invites")[0]["code"])
}

func TestClaimFirstAttemptConflictLeavesNoClaim(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, newTestEngine(t, cloud, "eve", t.TempDir()), "claim", map[string]any{"link": link, "name": "Eve"})
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	assert.Equal(t, CodeAlreadyClaimed, callErr(t, ali, "claim", map[string]any{"link": link, "name": "Ali"}))
	assert.Empty(t, list(call(t, ali, "view", nil), "claims"))
	assert.Equal(t, CodeAlreadyClaimed, callErr(t, ali, "claim", map[string]any{"link": link, "name": "Ali"}),
		"a dropped provisional claim does not turn a later 409 into success")
}

func TestApproveWithoutPairingID(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, newTestEngine(t, cloud, "ali", t.TempDir()), "claim", map[string]any{"link": link, "name": "Ali"})
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	cloud.noPairingID = true
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "decide", map[string]any{"invite_id": id, "approve": true}))
	inv := list(call(t, sara, "view", nil), "invites")
	require.Len(t, inv, 1)
	assert.Equal(t, "claimed", inv[0]["state"])
	assert.Equal(t, "Ali", inv[0]["volunteer_name"])
	cloud.noPairingID = false
	assert.Equal(t, CodeNoPendingClaim, callErr(t, sara, "decide", map[string]any{"invite_id": id, "approve": true}))
	assert.Len(t, list(call(t, sara, "view", nil), "invites"), 1, "a retry keeps the invite")
	sv := call(t, sara, "refresh", nil)
	assert.Empty(t, list(sv, "invites"))
	require.Len(t, list(sv, "helpers"), 1)
	assert.Equal(t, "Ali", list(sv, "helpers")[0]["name"])
}

func TestRefreshApprovedWithoutPairingID(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, newTestEngine(t, cloud, "ali", t.TempDir()), "claim", map[string]any{"link": link, "name": "Ali"})
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	cloud.loseAnswer["invites/decide"] = true
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "decide", map[string]any{"invite_id": id, "approve": true}))
	cloud.noPairingID = true
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "refresh", nil))
	assert.Len(t, list(call(t, sara, "view", nil), "invites"), 1, "the invite and its name are kept")
	cloud.noPairingID = false
	sv := call(t, sara, "refresh", nil)
	assert.Empty(t, list(sv, "invites"))
	require.Len(t, list(sv, "helpers"), 1)
	assert.Equal(t, "Ali", list(sv, "helpers")[0]["name"])
}

// TestLateApprovalStillNamed: an approval seen only after the 48 hours have
// passed still names the pairing on both sides.
func TestLateApprovalStillNamed(t *testing.T) {
	cloud := newFakeCloud()
	sara := newTestEngine(t, cloud, "sara", t.TempDir())
	ali := newTestEngine(t, cloud, "ali", t.TempDir())
	link := call(t, sara, "create_invite", map[string]any{"name": "Sara"})["link"]
	call(t, ali, "claim", map[string]any{"link": link, "name": "Ali"})
	id := list(call(t, sara, "refresh", nil), "invites")[0]["id"]
	cloud.loseAnswer["invites/decide"] = true
	callErr(t, sara, "decide", map[string]any{"invite_id": id, "approve": true})
	later := time.Now().Add(InviteTTL + time.Hour)
	sara.now = func() time.Time { return later }
	ali.now = func() time.Time { return later }
	assert.Equal(t, "Ali", list(call(t, sara, "refresh", nil), "helpers")[0]["name"])
	assert.Equal(t, "Sara", list(call(t, ali, "refresh", nil), "helping")[0]["name"])
}

func TestUnreadableStateStaysLocked(t *testing.T) {
	cloud := newFakeCloud()
	dir := t.TempDir()
	require.NoError(t, os.Mkdir(filepath.Join(dir, stateFile), 0o700)) // reads fail, not as missing
	e := NewEngine(dir, cloud.relay("sara"), nil)
	assert.Equal(t, CodeInternal, callErr(t, e, "unlock", map[string]any{"key": testKey}))
	assert.Equal(t, CodeLocked, callErr(t, e, "view", nil))
}

func TestBackupsAreNotOverwritten(t *testing.T) {
	cloud := newFakeCloud()
	dir := t.TempDir()
	path := filepath.Join(dir, stateFile)
	require.NoError(t, os.WriteFile(path, []byte("first unreadable state"), 0o600))
	call(t, NewEngine(dir, cloud.relay("sara"), nil), "unlock", map[string]any{"key": testKey})
	require.NoError(t, os.WriteFile(path, []byte("second unreadable state"), 0o600))
	out := call(t, NewEngine(dir, cloud.relay("sara"), nil), "unlock", map[string]any{"key": testKey})
	assert.Equal(t, true, out["keystore_reset"])
	first, err := os.ReadFile(path + ".bak")
	require.NoError(t, err)
	assert.Equal(t, "first unreadable state", string(first))
	second, err := os.ReadFile(path + ".bak.1")
	require.NoError(t, err)
	assert.Equal(t, "second unreadable state", string(second))
}

func TestResetRefusedWhenBackupFails(t *testing.T) {
	if os.PathSeparator != '/' || os.Geteuid() == 0 {
		t.Skip("needs POSIX permissions and a non-root user")
	}
	cloud := newFakeCloud()
	dir := t.TempDir()
	path := filepath.Join(dir, stateFile)
	require.NoError(t, os.WriteFile(path, []byte("unreadable state"), 0o600))
	require.NoError(t, os.Chmod(dir, 0o500))
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) })
	e := NewEngine(dir, cloud.relay("sara"), nil)
	assert.Equal(t, CodeInternal, callErr(t, e, "unlock", map[string]any{"key": testKey}))
	assert.Equal(t, CodeLocked, callErr(t, e, "create_invite", map[string]any{"name": "Sara"}))
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Equal(t, "unreadable state", string(data))
}

func TestEndAllHelpersOfflineWipesNames(t *testing.T) {
	cloud := newFakeCloud()
	dir := t.TempDir()
	sara := newTestEngine(t, cloud, "sara", dir)
	pair(t, cloud, sara, t.TempDir())
	cloud.down = true
	assert.Equal(t, CodeUnavailable, callErr(t, sara, "end_all_helpers", nil))
	for _, e := range []*Engine{sara, newTestEngine(t, cloud, "sara", dir)} {
		helpers := list(call(t, e, "view", nil), "helpers")
		require.Len(t, helpers, 1)
		assert.Equal(t, "", helpers[0]["name"])
	}
	cloud.down = false
	assert.Empty(t, list(call(t, sara, "end_all_helpers", nil), "helpers"))
}

func TestSaveTightensPermissions(t *testing.T) {
	if os.PathSeparator != '/' {
		t.Skip("POSIX permissions")
	}
	cloud := newFakeCloud()
	dir := filepath.Join(t.TempDir(), "helper")
	require.NoError(t, os.Mkdir(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, stateFile+".tmp"), nil, 0o644))
	sara := newTestEngine(t, cloud, "sara", dir)
	call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	info, err := os.Stat(dir)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o700), info.Mode().Perm())
	info, err = os.Stat(filepath.Join(dir, stateFile))
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
}

// TestFailedTombstoneRejectChangesNothing: when the reject of a late claim
// fails, refresh keeps the tombstone and does not rewrite the state.
func TestFailedTombstoneRejectChangesNothing(t *testing.T) {
	cloud := newFakeCloud()
	dir := t.TempDir()
	sara := newTestEngine(t, cloud, "sara", dir)
	inv := call(t, sara, "create_invite", map[string]any{"name": "Sara"})
	call(t, sara, "forget_invite", map[string]any{"invite_id": inv["invite_id"]})
	call(t, newTestEngine(t, cloud, "eve", t.TempDir()), "claim", map[string]any{"link": inv["link"], "name": "Eve"})
	before, err := os.ReadFile(filepath.Join(dir, stateFile))
	require.NoError(t, err)
	cloud.fail["invites/decide"] = 503
	call(t, sara, "refresh", nil)
	after, err := os.ReadFile(filepath.Join(dir, stateFile))
	require.NoError(t, err)
	assert.Equal(t, before, after, "nothing changed, so nothing was saved")
	require.Len(t, sara.st.Invites, 1)
	delete(cloud.fail, "invites/decide")
	call(t, sara, "refresh", nil)
	assert.Empty(t, sara.st.Invites, "the next refresh rejects it")
}
