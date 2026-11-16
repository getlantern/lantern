package helper

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// pairedPair returns an inviter and a volunteer engine with one approved
// pairing between them, and its ID.
func pairedPair(t *testing.T) (inviter, volunteer *Engine, pairingID string) {
	t.Helper()
	cloud := newFakeCloud()
	inviter = newTestEngine(t, cloud, "sara-device", t.TempDir())
	volunteer = newTestEngine(t, cloud, "ali-device", t.TempDir())
	link := call(t, inviter, "create_invite", map[string]any{"name": "Sara"})["link"].(string)
	call(t, volunteer, "claim", map[string]any{"link": link, "name": "Ali"})
	claimed := list(call(t, inviter, "refresh", nil), "invites")
	require.Len(t, claimed, 1)
	call(t, inviter, "decide", map[string]any{"invite_id": claimed[0]["id"], "approve": true})
	helping := list(call(t, volunteer, "refresh", nil), "helping")
	require.Len(t, helping, 1)
	return inviter, volunteer, helping[0]["pairing_id"].(string)
}

func TestLiveStatusMergesIntoHelpingRows(t *testing.T) {
	inviter, volunteer, id := pairedPair(t)

	row := list(call(t, volunteer, "view", nil), "helping")[0]
	_, has := row["connected"]
	assert.False(t, has, "no connected until radiance has answered")

	assert.True(t, volunteer.SetLive(true, map[string]bool{id: true}))
	assert.Equal(t, true, list(call(t, volunteer, "view", nil), "helping")[0]["connected"])

	assert.True(t, volunteer.SetLive(true, map[string]bool{id: false}))
	assert.Equal(t, false, list(call(t, volunteer, "view", nil), "helping")[0]["connected"])

	assert.True(t, volunteer.SetLive(false, nil))
	_, has = list(call(t, volunteer, "view", nil), "helping")[0]["connected"]
	assert.False(t, has, "unknown again once radiance stops answering")

	inviter.SetLive(true, map[string]bool{id: true})
	helper := list(call(t, inviter, "view", nil), "helpers")[0]
	_, has = helper["connected"]
	assert.False(t, has, "an inviter row never carries connected")
}

func TestLiveStatusMissingPairingIsNotConnected(t *testing.T) {
	_, volunteer, id := pairedPair(t)

	assert.True(t, volunteer.SetLive(true, map[string]bool{"someone-else": true}))
	row := list(call(t, volunteer, "view", nil), "helping")[0]
	assert.Equal(t, id, row["pairing_id"])
	assert.Equal(t, false, row["connected"])

	assert.True(t, volunteer.SetLive(true, map[string]bool{}))
	assert.Equal(t, false, list(call(t, volunteer, "view", nil), "helping")[0]["connected"])
}

func TestSetLiveReportsOnlyChanges(t *testing.T) {
	e := NewEngine(t.TempDir(), nil, nil)
	assert.False(t, e.SetLive(false, nil), "unknown is where it starts")
	assert.True(t, e.SetLive(true, nil), "known, nobody connected")
	assert.False(t, e.SetLive(true, map[string]bool{"p": false}), "a listed but not connected pairing reads the same")
	assert.True(t, e.SetLive(true, map[string]bool{"p": true}))
	assert.False(t, e.SetLive(true, map[string]bool{"p": true}))
	assert.True(t, e.SetLive(false, map[string]bool{"p": true}), "a failed read forgets the status")
}
