package lanterncore

import (
	"context"
	"errors"
	"slices"
	"strings"
	"testing"

	"github.com/getlantern/radiance/servers"
)

var errTunnel = errors.New("tunnel update failed")

// fakeServerStore holds user servers by tag. It refuses reserved tags the
// way radiance's AddServers does, and each call can be scripted: radiance
// saves (or deletes) before updating the tunnel, so an error does not say
// whether the store changed.
type fakeServerStore struct {
	byTag map[string]*servers.Server
	adds  int

	// addOutcomes and removeOutcomes script successive calls; past the end
	// a call applies and succeeds.
	addOutcomes    []outcome
	removeOutcomes []outcome
}

type outcome struct {
	apply bool
	err   error
}

func next(o *[]outcome) outcome {
	if len(*o) == 0 {
		return outcome{apply: true}
	}
	r := (*o)[0]
	*o = (*o)[1:]
	return r
}

func (f *fakeServerStore) GetServerByTag(_ context.Context, tag string) (*servers.Server, bool, error) {
	s, ok := f.byTag[tag]
	if !ok {
		return nil, false, nil
	}
	cp := *s
	return &cp, true, nil
}

func (f *fakeServerStore) RemoveServers(_ context.Context, tags []string) error {
	o := next(&f.removeOutcomes)
	if o.apply {
		for _, t := range tags {
			delete(f.byTag, t)
		}
	}
	return o.err
}

func (f *fakeServerStore) AddServers(_ context.Context, list servers.ServerList) error {
	f.adds++
	for _, s := range list.Servers {
		if slices.Contains(servers.ReservedTags(), s.Tag) {
			return servers.ErrReservedTag
		}
	}
	o := next(&f.addOutcomes)
	if o.apply {
		for _, s := range list.Servers {
			cp := *s
			f.byTag[s.Tag] = &cp
		}
	}
	return o.err
}

func (f *fakeServerStore) tags() []string {
	var t []string
	for k := range f.byTag {
		t = append(t, k)
	}
	slices.Sort(t)
	return t
}

func newRenameCore(t *testing.T, store *fakeServerStore) *LanternCore {
	store.byTag = map[string]*servers.Server{"home": {Tag: "home", Type: "vless"}}
	return &LanternCore{ctx: t.Context(), serverStore: store}
}

func TestUpdatePrivateServerNameRefusesReservedNames(t *testing.T) {
	for _, name := range servers.ReservedTags() {
		store := &fakeServerStore{}
		lc := newRenameCore(t, store)
		err := lc.UpdatePrivateServerName("home", name)
		if !errors.Is(err, servers.ErrReservedTag) {
			t.Errorf("rename to %q: error = %v, want ErrReservedTag", name, err)
		}
		if !slices.Equal(store.tags(), []string{"home"}) {
			t.Errorf("rename to %q: servers = %q", name, store.tags())
		}
		if store.adds != 0 {
			t.Errorf("rename to %q reached AddServers", name)
		}
	}
}

func TestUpdatePrivateServerNameRenames(t *testing.T) {
	store := &fakeServerStore{}
	lc := newRenameCore(t, store)
	if err := lc.UpdatePrivateServerName("home", "office"); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(store.tags(), []string{"office"}) {
		t.Errorf("servers = %q, want [office]", store.tags())
	}
}

func TestUpdatePrivateServerNameReconcilesAFailedAdd(t *testing.T) {
	for _, tt := range []struct {
		name    string
		add     []outcome
		remove  []outcome
		want    []string
		wantMsg string // in the error, besides the add error
	}{
		{
			name: "nothing saved, restore applies",
			add:  []outcome{{apply: false, err: errTunnel}},
			want: []string{"home"},
		},
		{
			name: "nothing saved, restore saves then errors",
			add:  []outcome{{apply: false, err: errTunnel}, {apply: true, err: errTunnel}},
			want: []string{"home"},
		},
		{
			name:    "nothing saved, restore saves nothing",
			add:     []outcome{{apply: false, err: errTunnel}, {apply: false, err: errTunnel}},
			want:    nil,
			wantMsg: "no longer stored",
		},
		{
			name:    "renamed copy saved: the rename stands",
			add:     []outcome{{apply: true, err: errTunnel}},
			want:    []string{"office"},
			wantMsg: `saved as "office"`,
		},
		{
			name: "both saved, cleanup applies",
			// The first remove (of home) reports success but keeps it.
			remove: []outcome{{apply: false}},
			add:    []outcome{{apply: true, err: errTunnel}},
			want:   []string{"home"},
		},
		{
			name:   "both saved, cleanup deletes then errors",
			remove: []outcome{{apply: false}, {apply: true, err: errTunnel}},
			add:    []outcome{{apply: true, err: errTunnel}},
			want:   []string{"home"},
		},
		{
			name:    "both saved, cleanup deletes nothing",
			remove:  []outcome{{apply: false}, {apply: false, err: errTunnel}},
			add:     []outcome{{apply: true, err: errTunnel}},
			want:    []string{"home", "office"},
			wantMsg: "both",
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeServerStore{}
			lc := newRenameCore(t, store)
			store.addOutcomes = tt.add
			store.removeOutcomes = tt.remove
			err := lc.UpdatePrivateServerName("home", "office")
			if !errors.Is(err, errTunnel) {
				t.Fatalf("error = %v, want the add error", err)
			}
			if tt.wantMsg != "" && !strings.Contains(err.Error(), tt.wantMsg) {
				t.Errorf("error = %q, want it to mention %q", err, tt.wantMsg)
			}
			if !slices.Equal(store.tags(), tt.want) {
				t.Errorf("servers = %q, want %q", store.tags(), tt.want)
			}
		})
	}
}
