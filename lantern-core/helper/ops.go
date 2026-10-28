package helper

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/json"
	"errors"
	"io"
	"slices"
	"time"

	"github.com/getlantern/broflake/common/helperinvite"
)

type createInviteReq struct {
	InviteHash     []byte `json:"invite_hash"`
	ApprovalPubkey []byte `json:"approval_pubkey"`
}

type claimReq struct {
	InviteHash      []byte `json:"invite_hash"`
	VolunteerPubkey []byte `json:"volunteer_pubkey"`
	VolunteerBlob   []byte `json:"volunteer_blob"`
}

type inviteRef struct {
	InviteHash []byte `json:"invite_hash"`
}

type inviteStatus struct {
	State           string `json:"state"`
	VolunteerPubkey []byte `json:"volunteer_pubkey"`
	VolunteerBlob   []byte `json:"volunteer_blob"`
	PairingID       string `json:"pairing_id"`
}

type decideReq struct {
	InviteHash  []byte `json:"invite_hash"`
	Approve     bool   `json:"approve"`
	ApprovalSig []byte `json:"approval_sig,omitempty"`
	InviterBlob []byte `json:"inviter_blob,omitempty"`
}

type pairingRef struct {
	PairingID string `json:"pairing_id"`
}

type listedPairing struct {
	PairingID   string    `json:"pairing_id"`
	Role        string    `json:"role"`
	InviterBlob []byte    `json:"inviter_blob"`
	Online      bool      `json:"online"`
	CreatedUnix int64JSON `json:"created_unix"`
}

const opRefreshTickets = "tickets/refresh"

func isCode(err error, code string) bool {
	var he *Error
	return errors.As(err, &he) && he.Code == code
}

func (e *Engine) invite(id string) *invite {
	for _, i := range e.st.Invites {
		if i.ID == id {
			return i
		}
	}
	return nil
}

func (e *Engine) pairing(id string) *pairing {
	for _, p := range e.st.Pairings {
		if p.ID == id {
			return p
		}
	}
	return nil
}

func (e *Engine) dropInvite(id string) {
	e.st.Invites = slices.DeleteFunc(e.st.Invites, func(i *invite) bool { return i.ID == id })
}

func (e *Engine) dropClaim(id string) {
	e.st.Claims = slices.DeleteFunc(e.st.Claims, func(c *claim) bool { return c.ID == id })
}

func (e *Engine) dropPairing(id string) {
	e.st.Pairings = slices.DeleteFunc(e.st.Pairings, func(p *pairing) bool { return p.ID == id })
}

func (e *Engine) addPairing(id, role, name string, since time.Time, inviteHash []byte) {
	if id == "" || e.pairing(id) != nil {
		return
	}
	e.st.Pairings = append(e.st.Pairings, &pairing{ID: id, Role: role, Name: name, Since: since, InviteHash: inviteHash})
}

// inviterPairings is the set of pairings in which this device is helped.
func (e *Engine) inviterPairings() map[string]bool {
	ids := map[string]bool{}
	for _, p := range e.st.Pairings {
		if p.Role == RoleInviter {
			ids[p.ID] = true
		}
	}
	return ids
}

func (e *Engine) prune() bool {
	cutoff := e.now().Add(-InviteTTL)
	ni, nc := len(e.st.Invites), len(e.st.Claims)
	e.st.Invites = slices.DeleteFunc(e.st.Invites, func(i *invite) bool { return i.Created.Before(cutoff) })
	e.st.Claims = slices.DeleteFunc(e.st.Claims, func(c *claim) bool { return c.Created.Before(cutoff) })
	return ni != len(e.st.Invites) || nc != len(e.st.Claims)
}

func (e *Engine) view(newHelping bool) View {
	v := View{Unlocked: true, MyName: e.st.MyName, NewHelping: newHelping, Activity: e.activity,
		Invites: []InviteView{}, Claims: []ClaimView{}, Helpers: []PairingView{}, Helping: []PairingView{}}
	for _, i := range e.st.Invites {
		if i.State == "cancelled" {
			continue
		}
		iv := InviteView{ID: i.ID, State: i.State, ExpiresUnix: i.Created.Add(InviteTTL).Unix(),
			Code: i.Code, VolunteerName: i.VolunteerName, InviterName: i.InviterName}
		if i.State == "pending" {
			iv.Link = helperinvite.Link(i.Secret)
		}
		v.Invites = append(v.Invites, iv)
	}
	for _, c := range e.st.Claims {
		v.Claims = append(v.Claims, ClaimView{ID: c.ID, Code: c.Code, ExpiresUnix: c.Created.Add(InviteTTL).Unix(),
			Provisional: c.Provisional})
	}
	for _, p := range e.st.Pairings {
		pv := PairingView{PairingID: p.ID, Name: p.Name, SinceUnix: p.Since.Unix()}
		if p.Role == RoleInviter {
			pv.Online = e.online[p.ID]
			v.Helpers = append(v.Helpers, pv)
		} else {
			v.Helping = append(v.Helping, pv)
		}
	}
	return v
}

func decodeArgs(args []byte, v any) error {
	if json.Unmarshal(args, v) != nil {
		return errCode(CodeInternal)
	}
	return nil
}

func (e *Engine) createInvite(ctx context.Context, args []byte) (any, error) {
	var a struct {
		Name string `json:"name"`
	}
	if err := decodeArgs(args, &a); err != nil {
		return nil, err
	}
	name, err := helperinvite.CleanName(a.Name)
	if err != nil {
		return nil, errCode(CodeBadName)
	}
	s, err := helperinvite.NewSecret(e.rand)
	if err != nil {
		return nil, errCode(CodeInternal)
	}
	if err := e.post(ctx, "invites", createInviteReq{InviteHash: helperinvite.InviteHash(s),
		ApprovalPubkey: helperinvite.ApprovalPublic(s)}, nil); err != nil {
		return nil, err
	}
	inv := &invite{ID: e.newID(), Secret: s, Created: e.now(), State: "pending", InviterName: name}
	e.st.Invites = append(e.st.Invites, inv)
	e.st.MyName = name
	if err := e.save(); err != nil {
		return nil, err
	}
	return map[string]string{"invite_id": inv.ID, "link": helperinvite.Link(s)}, nil
}

func (e *Engine) refresh(ctx context.Context) (any, error) {
	changed := false
	cutoff := e.now().Add(-InviteTTL)
	for _, inv := range slices.Clone(e.st.Invites) {
		var st inviteStatus
		err := e.post(ctx, "invites/get", inviteRef{InviteHash: helperinvite.InviteHash(inv.Secret)}, &st)
		if isCode(err, CodeNotFound) || (isCode(err, CodeDisabled) && inv.Created.Before(cutoff)) {
			// Expired and swept; or past its expiry on a device whose flag
			// is off, which can no longer ask about it: forget it rather
			// than fail every refresh.
			e.dropInvite(inv.ID)
			changed = true
			continue
		}
		if err != nil {
			if changed {
				_ = e.save()
			}
			return nil, err
		}
		if inv.State == "cancelled" {
			// A tombstone: reject any claim, so nobody waits on an approval
			// that cannot come, and forget it once it can no longer change.
			switch st.State {
			case "claimed":
				if err := e.post(ctx, "invites/decide", decideReq{InviteHash: helperinvite.InviteHash(inv.Secret)}, nil); err == nil ||
					isCode(err, CodeNoPendingClaim) {
					e.dropInvite(inv.ID)
					changed = true
				}
			case "approved", "rejected":
				e.dropInvite(inv.ID)
				changed = true
			}
			continue
		}
		switch st.State {
		case "claimed":
			if inv.State != "claimed" || !bytes.Equal(inv.VolunteerPub, st.VolunteerPubkey) {
				code := helperinvite.MatchingCode(helperinvite.DeriveKey(inv.Secret), st.VolunteerPubkey)
				if code == "" {
					// lantern-cloud sent a volunteer key that is not 32 bytes.
					if changed {
						_ = e.save()
					}
					return nil, errCode(CodeUnavailable)
				}
				inv.State = "claimed"
				inv.VolunteerPub = st.VolunteerPubkey
				inv.VolunteerName, _ = helperinvite.OpenName(helperinvite.VolunteerNameKey(inv.Secret), st.VolunteerBlob)
				inv.Code = code
				changed = true
			}
		case "approved":
			// Approved here or by an approve whose answer was lost.
			if st.PairingID == "" {
				// A malformed answer: keep the invite, which holds the name.
				if changed {
					_ = e.save()
				}
				return nil, errCode(CodeUnavailable)
			}
			e.addPairing(st.PairingID, RoleInviter, inv.VolunteerName, e.now(), nil)
			e.dropInvite(inv.ID)
			changed = true
		case "rejected":
			e.dropInvite(inv.ID)
			changed = true
		}
	}
	var list struct {
		Pairings []listedPairing `json:"pairings"`
	}
	err := e.post(ctx, "pairings", struct{}{}, &list)
	disabled := false
	if isCode(err, CodeDisabled) && len(e.st.Invites) == 0 {
		// A volunteer abroad has no helper_invites flag. lantern-cloud lets it
		// list pairings only while it holds a live claim or a pairing (Task 1),
		// so once its claim is rejected or expires, or its last pairing ends,
		// the answer is the gate's 404. A device with no invites of its own is
		// no inviter, so that answer means it holds nothing: an empty list.
		// Only the volunteer side is dropped: an inviter whose flag is turned
		// off, or any other such 404, must never wipe its helpers and their
		// names.
		err = nil
		disabled = true
	}
	if err != nil {
		if changed {
			_ = e.save()
		}
		return nil, err
	}
	var merged, newHelping bool
	if disabled {
		merged = e.dropVolunteerSide()
	} else {
		merged, newHelping = e.mergePairings(list.Pairings)
	}
	changed = changed || merged
	if merged {
		// New or ended pairings: ticket sources fetch at their next read,
		// so a new pairing's rooms work within seconds.
		_ = e.post(ctx, opRefreshTickets, struct{}{}, nil)
	}
	if e.activityFn != nil {
		if a, err := e.activityFn(ctx); err == nil {
			e.activity = &a
		}
	}
	// Prune last, so an invite or claim approved just before it expired
	// still yields its pairing's name.
	if e.prune() {
		changed = true
	}
	if changed {
		if err := e.save(); err != nil {
			return nil, err
		}
	}
	return e.view(newHelping), nil
}

// dropVolunteerSide forgets every claim and every pairing this device
// volunteers in, leaving the pairings where it is helped.
func (e *Engine) dropVolunteerSide() bool {
	n, c := len(e.st.Pairings), len(e.st.Claims)
	e.online = map[string]bool{}
	e.st.Claims = nil
	e.st.Pairings = slices.DeleteFunc(e.st.Pairings, func(p *pairing) bool { return p.Role == RoleVolunteer })
	return n != len(e.st.Pairings) || c > 0
}

// mergePairings makes the local pairings match lantern-cloud's list. A new
// pairing this device volunteers for takes its inviter's name from the
// pending claim whose key opens the blob, and that claim is done.
func (e *Engine) mergePairings(listed []listedPairing) (changed, newHelping bool) {
	seen := map[string]bool{}
	e.online = map[string]bool{}
	for _, lp := range listed {
		if lp.PairingID == "" {
			// A malformed entry: nothing to add, and not a new pairing.
			continue
		}
		seen[lp.PairingID] = true
		if lp.Role == RoleInviter {
			e.online[lp.PairingID] = lp.Online
		}
		if e.pairing(lp.PairingID) != nil {
			continue
		}
		name := ""
		var hash []byte
		if lp.Role == RoleVolunteer {
			newHelping = true
			name, hash = e.claimName(lp.InviterBlob)
		}
		e.addPairing(lp.PairingID, lp.Role, name, time.Unix(int64(lp.CreatedUnix), 0), hash)
		changed = true
	}
	n := len(e.st.Pairings)
	e.st.Pairings = slices.DeleteFunc(e.st.Pairings, func(p *pairing) bool { return !seen[p.ID] })
	return changed || n != len(e.st.Pairings), newHelping
}

// claimName returns the inviter's name and the invite hash of the pending
// claim whose key opens blob, and drops that claim.
func (e *Engine) claimName(blob []byte) (string, []byte) {
	if len(blob) == 0 {
		return "", nil
	}
	for _, c := range e.st.Claims {
		if name, err := helperinvite.OpenName(helperinvite.InviterNameKey(c.Secret), blob); err == nil {
			e.dropClaim(c.ID)
			return name, helperinvite.InviteHash(c.Secret)
		}
	}
	return "", nil
}

func (e *Engine) decide(ctx context.Context, args []byte) (any, error) {
	var a struct {
		InviteID string `json:"invite_id"`
		Approve  bool   `json:"approve"`
	}
	if err := decodeArgs(args, &a); err != nil {
		return nil, err
	}
	inv := e.invite(a.InviteID)
	if inv == nil || inv.State != "claimed" {
		return nil, errCode(CodeNoPendingClaim)
	}
	hash := helperinvite.InviteHash(inv.Secret)
	if !a.Approve {
		if err := e.post(ctx, "invites/decide", decideReq{InviteHash: hash}, nil); err != nil {
			return nil, err
		}
		e.dropInvite(inv.ID)
	} else {
		name := inv.InviterName
		if name == "" {
			name = e.st.MyName // an invite saved before names were kept per invite
		}
		appr, err := helperinvite.NewApproval(inv.Secret, inv.VolunteerPub, name, e.rand)
		switch {
		case errors.Is(err, helperinvite.ErrKey):
			// VolunteerPub came from lantern-cloud: a malformed answer.
			return nil, errCode(CodeUnavailable)
		case errors.Is(err, helperinvite.ErrName):
			return nil, errCode(CodeBadName)
		case err != nil:
			return nil, errCode(CodeInternal)
		}
		var resp struct {
			PairingID string `json:"pairing_id"`
		}
		if err := e.post(ctx, "invites/decide", decideReq{InviteHash: hash, Approve: true,
			ApprovalSig: appr.Signature, InviterBlob: appr.InviterBlob}, &resp); err != nil {
			return nil, err
		}
		if resp.PairingID == "" {
			// A malformed answer: keep the claimed invite and its name. The
			// next refresh reads the approval with its pairing.
			return nil, errCode(CodeUnavailable)
		}
		e.addPairing(resp.PairingID, RoleInviter, inv.VolunteerName, e.now(), nil)
		e.dropInvite(inv.ID)
	}
	if err := e.save(); err != nil {
		return nil, err
	}
	return e.view(false), nil
}

func (e *Engine) forgetInvite(ctx context.Context, args []byte) (any, error) {
	var a struct {
		InviteID string `json:"invite_id"`
	}
	if err := decodeArgs(args, &a); err != nil {
		return nil, err
	}
	inv := e.invite(a.InviteID)
	if inv == nil {
		return e.view(false), nil
	}
	if err := e.cancelInvite(ctx, inv); err != nil {
		return nil, err
	}
	if err := e.save(); err != nil {
		return nil, err
	}
	return e.view(false), nil
}

// cancelInvite rejects a claimed invite and forgets it. An unclaimed one
// becomes a tombstone (there is no RPC to delete it), which refresh uses to
// reject any later claim until it expires.
func (e *Engine) cancelInvite(ctx context.Context, inv *invite) error {
	if inv.State == "claimed" {
		err := e.post(ctx, "invites/decide", decideReq{InviteHash: helperinvite.InviteHash(inv.Secret)}, nil)
		if err != nil && !isCode(err, CodeNoPendingClaim) && !isCode(err, CodeNotFound) {
			return err
		}
		e.dropInvite(inv.ID)
		return nil
	}
	inv.State = "cancelled"
	inv.InviterName = ""
	return nil
}

func (e *Engine) claim(ctx context.Context, args []byte) (any, error) {
	var a struct {
		Link string `json:"link"`
		Name string `json:"name"`
	}
	if err := decodeArgs(args, &a); err != nil {
		return nil, err
	}
	s, err := helperinvite.ParseLink(a.Link)
	if err != nil {
		return nil, errCode(CodeBadLink)
	}
	for _, inv := range e.st.Invites {
		if bytes.Equal(inv.Secret, s) {
			return nil, errCode(CodeOwnInvite)
		}
	}
	hash := helperinvite.InviteHash(s)
	for _, p := range e.st.Pairings {
		if p.Role == RoleVolunteer && len(p.InviteHash) > 0 && bytes.Equal(p.InviteHash, hash) {
			// Re-opened after approval: a new claim would be lantern-cloud's
			// 409, which reads as a link someone else used.
			return nil, errCode(CodeAlreadyHelping)
		}
	}
	// A claim already made for this link, confirmed or not, is answered with
	// its own code. A confirmed one is not sent again.
	var cl *claim
	for _, c := range e.st.Claims {
		if bytes.Equal(c.Secret, s) {
			cl = c
		}
	}
	if cl != nil && !cl.Provisional {
		return map[string]string{"claim_id": cl.ID, "code": cl.Code}, nil
	}
	// lantern-cloud's claim is not idempotent: a second one, even identical,
	// is a 409. So the claim is saved before it is sent, and a claim whose
	// answer was lost is retried with the same request; a 409 to that retry
	// means the first one landed. Were it someone else's claim, the
	// inviter's code would not match this one.
	retry := cl != nil
	if !retry {
		if len(e.st.DeviceSeed) == 0 {
			seed := make([]byte, ed25519.SeedSize)
			if _, err := io.ReadFull(e.rand, seed); err != nil {
				return nil, errCode(CodeInternal)
			}
			e.st.DeviceSeed = seed
		}
		c, err := helperinvite.NewClaim(s, e.st.DeviceSeed, a.Name, e.rand)
		if errors.Is(err, helperinvite.ErrName) {
			return nil, errCode(CodeBadName)
		}
		if err != nil || c.Code == "" {
			// ErrKey here is our own device seed: internal.
			return nil, errCode(CodeInternal)
		}
		name, _ := helperinvite.CleanName(a.Name)
		cl = &claim{ID: e.newID(), Secret: s, Created: e.now(), Code: c.Code, Name: name,
			Provisional: true, Blob: c.VolunteerBlob}
		e.st.Claims = append(e.st.Claims, cl)
		if err := e.save(); err != nil {
			e.dropClaim(cl.ID)
			return nil, err
		}
	}
	priv, err := helperinvite.DeviceKey(e.st.DeviceSeed)
	if err != nil {
		return nil, errCode(CodeInternal)
	}
	err = e.post(ctx, "invites/claim", claimReq{InviteHash: hash,
		VolunteerPubkey: priv.Public().(ed25519.PublicKey), VolunteerBlob: cl.Blob}, nil)
	switch {
	case err == nil, retry && isCode(err, CodeAlreadyClaimed):
	case isCode(err, CodeUnavailable):
		return nil, err // kept, for a retry
	default:
		e.dropClaim(cl.ID)
		_ = e.save()
		return nil, err
	}
	cl.Provisional, cl.Blob = false, nil
	if cl.Name != "" {
		e.st.MyName = cl.Name
	}
	if err := e.save(); err != nil {
		return nil, err
	}
	return map[string]string{"claim_id": cl.ID, "code": cl.Code}, nil
}

func (e *Engine) endPairing(ctx context.Context, args []byte) (any, error) {
	var a struct {
		PairingID string `json:"pairing_id"`
	}
	if err := decodeArgs(args, &a); err != nil {
		return nil, err
	}
	p := e.pairing(a.PairingID)
	if p == nil {
		return nil, errCode(CodeNotFound)
	}
	if err := e.post(ctx, "pairings/end", pairingRef{PairingID: p.ID}, nil); err != nil && !isCode(err, CodeNotFound) {
		return nil, err
	}
	e.dropPairing(p.ID)
	if err := e.save(); err != nil {
		return nil, err
	}
	return e.view(false), nil
}

// endAllHelpers is "remove all helpers": it ends every pairing in which this
// device is helped, rejects claimed invites, and turns unclaimed ones into
// tombstones without names, so a seized phone holds no helper names. It
// blanks the names before any request, and saves after each step, so a
// failure part way keeps what was done.
func (e *Engine) endAllHelpers(ctx context.Context) (any, error) {
	// Names go first, and are saved before any request, so they are gone
	// even when lantern-cloud cannot be reached.
	for _, p := range e.st.Pairings {
		if p.Role == RoleInviter {
			p.Name = ""
		}
	}
	for _, c := range e.st.Claims {
		c.Name = ""
	}
	for _, inv := range e.st.Invites {
		inv.VolunteerName = ""
	}
	if err := e.save(); err != nil {
		return nil, err
	}
	for _, p := range slices.Clone(e.st.Pairings) {
		if p.Role != RoleInviter {
			continue
		}
		if err := e.post(ctx, "pairings/end", pairingRef{PairingID: p.ID}, nil); err != nil && !isCode(err, CodeNotFound) {
			_ = e.save()
			return nil, err
		}
		e.dropPairing(p.ID)
	}
	for _, inv := range slices.Clone(e.st.Invites) {
		if err := e.cancelInvite(ctx, inv); err != nil {
			_ = e.save()
			return nil, err
		}
	}
	if err := e.save(); err != nil {
		return nil, err
	}
	return e.view(false), nil
}
