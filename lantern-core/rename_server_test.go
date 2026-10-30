package lanterncore

import (
	"context"
	"errors"
	"slices"
	"testing"

	"github.com/getlantern/radiance/servers"
)

// fakeServerStore holds user servers by tag, refusing reserved tags the way
// radiance's AddServers does.
type fakeServerStore struct {
	byTag map[string]*servers.Server
	adds  int
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
	for _, t := range tags {
		delete(f.byTag, t)
	}
	return nil
}

func (f *fakeServerStore) AddServers(_ context.Context, list servers.ServerList) error {
	f.adds++
	for _, s := range list.Servers {
		if slices.Contains(servers.ReservedTags(), s.Tag) {
			return servers.ErrReservedTag
		}
	}
	for _, s := range list.Servers {
		cp := *s
		f.byTag[s.Tag] = &cp
	}
	return nil
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
		if _, ok := store.byTag["home"]; !ok {
			t.Errorf("rename to %q lost the server", name)
		}
		if store.adds != 0 {
			t.Errorf("rename to %q reached AddServers", name)
		}
	}
}

func TestUpdatePrivateServerNameRestoresOriginal(t *testing.T) {
	store := &fakeServerStore{}
	lc := newRenameCore(t, store)
	failOnce := &failingFirstAdd{fakeServerStore: store}
	lc.serverStore = failOnce
	if err := lc.UpdatePrivateServerName("home", "office"); err == nil {
		t.Fatal("rename succeeded; want the add failure")
	}
	got, ok := store.byTag["home"]
	if !ok {
		t.Fatal("original server was not restored")
	}
	if got.Type != "vless" {
		t.Errorf("restored server type = %q, want vless", got.Type)
	}
	if _, ok := store.byTag["office"]; ok {
		t.Error("renamed server exists after a failed add")
	}
}

func TestUpdatePrivateServerNameRenames(t *testing.T) {
	store := &fakeServerStore{}
	lc := newRenameCore(t, store)
	if err := lc.UpdatePrivateServerName("home", "office"); err != nil {
		t.Fatal(err)
	}
	if _, ok := store.byTag["home"]; ok {
		t.Error("old tag kept")
	}
	if s, ok := store.byTag["office"]; !ok || s.Tag != "office" {
		t.Errorf("renamed server = %+v, %v", s, ok)
	}
}

// failingFirstAdd fails the first AddServers (the renamed copy) and lets
// the restore through.
type failingFirstAdd struct {
	*fakeServerStore
	failed bool
}

func (f *failingFirstAdd) AddServers(ctx context.Context, list servers.ServerList) error {
	if !f.failed {
		f.failed = true
		return errors.New("backend refused")
	}
	return f.fakeServerStore.AddServers(ctx, list)
}
