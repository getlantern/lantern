package server

import (
	"fmt"
	"github.com/blang/semver"
	"os"
	"path"
	"testing"
)

var testClient *ReleaseManager

var (
	ghAccountOwner      = "getlantern"
	ghAccountRepository = "lantern"
)

func init() {
	if v := os.Getenv("GH_ACCOUNT_OWNER"); v != "" {
		ghAccountOwner = v
	}
	if v := os.Getenv("GH_ACCOUNT_REPOSITORY"); v != "" {
		ghAccountRepository = v
	}
}

func TestSplitUpdateAsset(t *testing.T) {
	var err error
	var info *AssetInfo

	if info, err = getAssetInfo("update_darwin_386.dmg"); err != nil {
		t.Fatal(fmt.Errorf("Failed to get asset info: %q", err))
	}
	if info.OS != OS.Darwin || info.Arch != Arch.X86 {
		t.Fatal("Failed to identify update asset.")
	}

	if info, err = getAssetInfo("update_darwin_amd64.v1"); err != nil {
		t.Fatal(fmt.Errorf("Failed to get asset info: %q", err))
	}
	if info.OS != OS.Darwin || info.Arch != Arch.X64 {
		t.Fatal("Failed to identify update asset.")
	}

	if info, err = getAssetInfo("update_linux_arm"); err != nil {
		t.Fatal(fmt.Errorf("Failed to get asset info: %q", err))
	}
	if info.OS != OS.Linux || info.Arch != Arch.ARM {
		t.Fatal("Failed to identify update asset.")
	}

	if info, err = getAssetInfo("update_windows_386"); err != nil {
		t.Fatal(fmt.Errorf("Failed to get asset info: %q", err))
	}
	if info.OS != OS.Windows || info.Arch != Arch.X86 {
		t.Fatal("Failed to identify update asset.")
	}

	if _, err = getAssetInfo("update_osx_386"); err == nil {
		t.Fatalf("Should have ignored the release, \"osx\" is not a valid OS value.")
	}
}

func TestNewClient(t *testing.T) {
	testClient = NewReleaseManager(ghAccountOwner, ghAccountRepository)
	if testClient == nil {
		t.Fatal("Failed to create new client.")
	}
}

func TestListReleases(t *testing.T) {
	if _, err := testClient.getReleases(); err != nil {
		t.Fatal(fmt.Errorf("Failed to pull releases: %q", err))
	}
}

func TestUpdateAssetsMap(t *testing.T) {
	if err := testClient.UpdateAssetsMap(); err != nil {
		t.Fatal(fmt.Errorf("Failed to update assets map: %q", err))
	}
	if testClient.updateAssetsMap == nil {
		t.Fatal("Assets map should not be nil at this point.")
	}
	if len(testClient.updateAssetsMap) == 0 {
		t.Fatal("Assets map is empty.")
	}
	if testClient.latestAssetsMap == nil {
		t.Fatal("Assets map should not be nil at this point.")
	}
	if len(testClient.latestAssetsMap) == 0 {
		t.Fatal("Assets map is empty.")
	}
}

func TestDownloadOldestVersionAndUpgradeIt(t *testing.T) {

	if len(testClient.updateAssetsMap) == 0 {
		t.Fatal("Assets map is empty.")
	}

	oldestVersionMap := make(map[string]map[string]*Asset)

	// Using the updateAssetsMap to look for the oldest version of each release.
	for os := range testClient.updateAssetsMap {
		for arch := range testClient.updateAssetsMap[os] {
			var oldestAsset *Asset

			for i := range testClient.updateAssetsMap[os][arch] {
				asset := testClient.updateAssetsMap[os][arch][i]
				if oldestAsset == nil {
					oldestAsset = asset
				} else {
					if asset.v.LT(oldestAsset.v) {
						oldestAsset = asset
					}
				}
			}
			if oldestAsset != nil {
				if oldestVersionMap[os] == nil {
					oldestVersionMap[os] = make(map[string]*Asset)
				}

				oldestVersionMap[os][arch] = oldestAsset
			}
		}
	}

	// Let's download each one of the oldest versions.
	var err error
	var p *Patch

	if len(oldestVersionMap) == 0 {
		t.Fatal("No older software versions to test with.")
	}

	tests := 0

	for os := range oldestVersionMap {
		for arch := range oldestVersionMap[os] {
			asset := oldestVersionMap[os][arch]
			newAsset := testClient.latestAssetsMap[os][arch]

			t.Logf("Upgrading %v to %v (%s/%s)", asset.v, newAsset.v, os, arch)

			if asset == newAsset {
				t.Logf("Skipping version %s %s %s", os, arch, asset.v)
				// Skipping
				continue
			}

			// Generate a binary diff of the two assets.
			if p, err = generatePatch(asset.URL, newAsset.URL); err != nil {
				t.Fatal(fmt.Errorf("Unable to generate patch: %q", err))
			}

			// Apply patch.
			var oldAssetFile string
			if oldAssetFile, err = downloadAsset(asset.URL); err != nil {
				t.Fatal(err)
			}

			var newAssetFile string
			if newAssetFile, err = downloadAsset(newAsset.URL); err != nil {
				t.Fatal(err)
			}

			patchedFile := "_tests/" + path.Base(asset.URL)

			if err = bspatch(oldAssetFile, patchedFile, p.File); err != nil {
				t.Fatal(fmt.Sprintf("Failed to apply binary diff: %q", err))
			}

			// Compare the two versions.
			if fileHash(oldAssetFile) == fileHash(newAssetFile) {
				t.Fatal("Nothing to update, probably not a good test case.")
			}

			if fileHash(patchedFile) != fileHash(newAssetFile) {
				t.Fatal("File hashes after patch must be equal.")
			}

			var cs string
			if cs, err = checksumForFile(patchedFile); err != nil {
				t.Fatal("Could not get checksum for %s: %q", patchedFile, err)
			}

			if cs == asset.Checksum {
				t.Fatal("Computed checksum for patchedFile must be different than the stored older asset checksum.")
			}

			if cs != newAsset.Checksum {
				t.Fatal("Computed checksum for patchedFile must be equal to the stored newer asset checksum.")
			}

			var ss string
			if ss, err = signatureForFile(patchedFile); err != nil {
				t.Fatal("Could not get signature for %s: %q", patchedFile, err)
			}

			if ss == asset.Signature {
				t.Fatal("Computed signature for patchedFile must be different than the stored older asset signature.")
			}

			if ss != newAsset.Signature {
				t.Fatal("Computed signature for patchedFile must be equal to the stored newer asset signature.")
			}

			tests++

		}
	}

	if tests == 0 {
		t.Fatal("Seems like there is not any newer software version to test with.")
	}

	// Let's walk over the array again but using CheckForUpdate instead.
	for os := range oldestVersionMap {
		for arch := range oldestVersionMap[os] {
			asset := oldestVersionMap[os][arch]
			params := Params{
				AppVersion: asset.v.String(),
				OS:         asset.OS,
				Arch:       asset.Arch,
				Checksum:   asset.Checksum,
			}

			// fmt.Printf("params: %s", params)

			r, err := testClient.CheckForUpdate(&params)
			if err != nil {
				if err == ErrNoUpdateAvailable {
					// That's OK, let's make sure.
					newAsset := testClient.latestAssetsMap[os][arch]
					if asset != newAsset {
						t.Fatal("CheckForUpdate said no update was available!")
					}
				} else {
					t.Fatal("CheckForUpdate: ", err)
				}
			}

			if r.PatchType != PATCHTYPE_BSDIFF {
				t.Fatal("Expecting no patch.")
			}

			if r.Version != testClient.latestAssetsMap[os][arch].v.String() {
				t.Fatal("Expecting %v, got %v.", testClient.latestAssetsMap[os][arch].v, r.Version)
			}
		}
	}

	// Let's walk again using an odd checksum.
	for os := range oldestVersionMap {
		for arch := range oldestVersionMap[os] {
			asset := oldestVersionMap[os][arch]
			params := Params{
				AppVersion: asset.v.String(),
				OS:         asset.OS,
				Arch:       asset.Arch,
				Checksum:   "?",
			}

			r, err := testClient.CheckForUpdate(&params)
			if err != nil {
				if err == ErrNoUpdateAvailable {
					// That's OK, let's make sure.
					newAsset := testClient.latestAssetsMap[os][arch]
					if asset != newAsset {
						t.Fatal("CheckForUpdate said no update was available!")
					}
				} else {
					t.Fatal("CheckForUpdate: ", err)
				}
			}

			if r.PatchType != PATCHTYPE_NONE {
				t.Fatal("Expecting no patch.")
			}

			if r.Version != testClient.latestAssetsMap[os][arch].v.String() {
				t.Fatal("Expecting %v, got %v.", testClient.latestAssetsMap[os][arch].v, r.Version)
			}
		}
	}
}

func TestDownloadManotoBetaAndUpgradeIt(t *testing.T) {

	if r := semver.MustParse("2.0.0+manoto").Compare(semver.MustParse("2.0.0+stable")); r != 0 {
		t.Fatalf("Expecting 2.0.0+manoto to be equal to 2.0.0+stable, got: %d", r)
	}

	if r := semver.MustParse("2.0.0+manoto").Compare(semver.MustParse("2.0.1")); r != -1 {
		t.Fatalf("Expecting 2.0.0+manoto to be lower than 2.0.1, got: %d", r)
	}

	if r := semver.MustParse("2.0.0+stable").Compare(semver.MustParse("9999.99.99")); r != -1 {
		t.Fatalf("Expecting 2.0.0+manoto to be lower than 9999.99.99, got: %d", r)
	}

	if len(testClient.updateAssetsMap) == 0 {
		t.Fatal("Assets map is empty.")
	}

	oldestVersionMap := make(map[string]map[string]*Asset)

	// Using the updateAssetsMap to look for the oldest version of each release.
	for os := range testClient.updateAssetsMap {
		for arch := range testClient.updateAssetsMap[os] {
			var oldestAsset *Asset

			for i := range testClient.updateAssetsMap[os][arch] {
				asset := testClient.updateAssetsMap[os][arch][i]
				if asset.v.String() == semver.MustParse(manotoBeta8).String() {
					if !buildStringContainsManoto(asset.v) {
						t.Fatal(`Build string must contain the word "manoto"`)
					}
					oldestAsset = asset
				}
			}

			if oldestAsset != nil {
				if oldestVersionMap[os] == nil {
					oldestVersionMap[os] = make(map[string]*Asset)
				}
				oldestVersionMap[os][arch] = oldestAsset
			}
		}
	}

	// Let's download each one of the oldest versions.
	if len(oldestVersionMap) == 0 {
		t.Fatal("No older software versions to test with.")
	}

	// Let's walk over the array again but using CheckForUpdate instead.
	for os := range oldestVersionMap {
		for arch := range oldestVersionMap[os] {
			asset := oldestVersionMap[os][arch]
			params := Params{
				AppVersion: asset.v.String(),
				OS:         asset.OS,
				Arch:       asset.Arch,
				Checksum:   asset.Checksum,
			}

			if params.AppVersion != manotoBeta8 {
				t.Fatal("Expecting Manoto beta8.")
			}

			r, err := testClient.CheckForUpdate(&params)
			if err != nil {
				t.Fatal("CheckForUpdate: ", err)
			}

			t.Logf("Upgrading %v to %v (%s/%s)", asset.v, r.Version, os, arch)

			if r.Version != manotoBeta8Upgrade {
				t.Fatal("Expecting %s.", manotoBeta8Upgrade)
			}
		}
	}

}
