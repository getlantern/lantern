package helper

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"slices"
	"strconv"
	"sync"

	"github.com/getlantern/broflake/common/helperinvite"
)

type fakeInvite struct {
	inviter, volunteer                       string
	approvalPub, volunteerPub, volunteerBlob []byte
	state, pairingID                         string
}

type fakePairing struct {
	id, inviter, volunteer string
	inviterBlob            []byte
}

// fakeCloud answers HelperService as lantern-cloud does, in memory, for any
// number of devices. Each engine relays through relay(device).
type fakeCloud struct {
	mu       sync.Mutex
	invites  map[string]*fakeInvite
	pairings []*fakePairing
	online   map[string]bool
	disabled bool
	down     bool
	// flagOff lists devices without the helper_invites flag. They get
	// lantern-cloud's gate (Task 1): claims always; pairings, ending and
	// tickets only while they hold a live claim or a pairing; nothing else.
	flagOff map[string]bool
}

func newFakeCloud() *fakeCloud {
	return &fakeCloud{invites: map[string]*fakeInvite{}, online: map[string]bool{}, flagOff: map[string]bool{}}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}

// flagFreeAllowed mirrors lantern-cloud's volunteerOrNotFound for a flag-off
// device. The caller holds f.mu.
func (f *fakeCloud) flagFreeAllowed(device, op string) bool {
	switch op {
	case "invites/claim", "tickets/refresh":
		return true
	case "pairings", "pairings/end":
		for _, p := range f.pairings {
			if p.volunteer == device {
				return true
			}
		}
		for _, inv := range f.invites {
			if inv.state == "claimed" && inv.volunteer == device {
				return true
			}
		}
	}
	return false
}

func (f *fakeCloud) relay(device string) Relay {
	return func(_ context.Context, op string, body []byte) (int, []byte, string, error) {
		f.mu.Lock()
		defer f.mu.Unlock()
		if f.down {
			return 0, nil, "", fmt.Errorf("connection refused")
		}
		if f.disabled || (f.flagOff[device] && !f.flagFreeAllowed(device, op)) {
			return 404, nil, "404 page not found", nil
		}
		var req struct {
			InviteHash      []byte `json:"invite_hash"`
			ApprovalPubkey  []byte `json:"approval_pubkey"`
			VolunteerPubkey []byte `json:"volunteer_pubkey"`
			VolunteerBlob   []byte `json:"volunteer_blob"`
			Approve         bool   `json:"approve"`
			ApprovalSig     []byte `json:"approval_sig"`
			InviterBlob     []byte `json:"inviter_blob"`
			PairingID       string `json:"pairing_id"`
		}
		if err := json.Unmarshal(body, &req); err != nil {
			return 400, nil, "bad body", nil
		}
		key := hex.EncodeToString(req.InviteHash)
		switch op {
		case "invites":
			f.invites[key] = &fakeInvite{inviter: device, approvalPub: req.ApprovalPubkey, state: "pending"}
			return 200, []byte("{}"), "", nil
		case "invites/claim":
			inv := f.invites[key]
			if inv == nil || inv.state != "pending" || inv.inviter == device {
				return 409, nil, "invite already claimed or expired", nil
			}
			inv.state, inv.volunteer, inv.volunteerPub, inv.volunteerBlob = "claimed", device, req.VolunteerPubkey, req.VolunteerBlob
			return 200, []byte("{}"), "", nil
		case "invites/get":
			inv := f.invites[key]
			if inv == nil || inv.inviter != device {
				return 404, nil, "no such invite", nil
			}
			return 200, mustJSON(map[string]any{"state": inv.state, "volunteer_pubkey": inv.volunteerPub,
				"volunteer_blob": inv.volunteerBlob, "pairing_id": inv.pairingID}), "", nil
		case "invites/decide":
			inv := f.invites[key]
			if inv == nil || inv.inviter != device {
				return 404, nil, "no such invite", nil
			}
			if inv.state != "claimed" {
				return 409, nil, "invite has no pending claim", nil
			}
			if !req.Approve {
				inv.state = "rejected"
				return 200, []byte("{}"), "", nil
			}
			if !ed25519.Verify(inv.approvalPub, helperinvite.ApprovalMessage(req.InviteHash, inv.volunteerPub), req.ApprovalSig) {
				return 403, nil, "approval signature does not match", nil
			}
			id := fmt.Sprintf("00000000-0000-4000-8000-%012d", len(f.pairings)+1)
			inv.state, inv.pairingID = "approved", id
			f.pairings = append(f.pairings, &fakePairing{id: id, inviter: device, volunteer: inv.volunteer, inviterBlob: req.InviterBlob})
			return 200, mustJSON(map[string]any{"pairing_id": id}), "", nil
		case "pairings":
			out := []map[string]any{}
			for _, p := range f.pairings {
				switch device {
				case p.inviter:
					out = append(out, map[string]any{"pairing_id": p.id, "role": "inviter",
						"online": f.online[p.volunteer], "created_unix": strconv.Itoa(1800000000)})
				case p.volunteer:
					m := map[string]any{"pairing_id": p.id, "role": "volunteer", "created_unix": "1800000000"}
					if len(p.inviterBlob) > 0 {
						m["inviter_blob"] = p.inviterBlob
						p.inviterBlob = nil // delivered once, as lantern-cloud does
					}
					out = append(out, m)
				}
			}
			return 200, mustJSON(map[string]any{"pairings": out}), "", nil
		case "pairings/end":
			for i, p := range f.pairings {
				if p.id == req.PairingID && (p.inviter == device || p.volunteer == device) {
					f.pairings = slices.Delete(f.pairings, i, i+1)
					return 200, []byte("{}"), "", nil
				}
			}
			return 404, nil, "no such pairing", nil
		case "tickets/refresh":
			return 200, []byte("{}"), "", nil
		}
		return 400, nil, "unknown op", nil
	}
}
