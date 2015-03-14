package server

import (
	"testing"
)

func TestCompareVersions(t *testing.T) {
	if VersionCompare("v1.0.0", "v2.0.0") != Higher {
		t.Fatalf("Expecting value: Higher")
	}
	if VersionCompare("v1.0.0", "v1.0.0") != Equal {
		t.Fatalf("Expecting value: Equal")
	}
	if VersionCompare("v1.0.0", "v0.1.0") != Lower {
		t.Fatalf("Expecting value: Lower")
	}
	if VersionCompare("v1.1.99", "v1.1.999") != Higher {
		t.Fatalf("Expecting value: Higher")
	}
	if VersionCompare("v1.1.99.1", "v1.1.999") != Higher {
		t.Fatalf("Expecting value: Higher")
	}
	if VersionCompare("v1.1.0.0.0", "v1.1") != Equal {
		t.Fatalf("Expecting value: Equal")
	}
	if VersionCompare("v1.1", "v1.1.0.0") != Equal {
		t.Fatalf("Expecting value: Equal")
	}
	if VersionCompare("v1.1.", "v1.1.0.") != Equal {
		t.Fatalf("Expecting value: Equal")
	}
	if VersionCompare("v1.1.", "v1.1.0...") != Equal {
		t.Fatalf("Expecting value: Equal")
	}
	if VersionCompare("v1.0.0.1", "v1.0.0") != Lower {
		t.Fatalf("Expecting value: Lower")
	}
	if VersionCompare("v2.0.0.1.1", "v2.1.0.99") != Higher {
		t.Fatalf("Expecting value: Higher")
	}
	// We don't actually compare beta or alpha strings yet, this is just a test
	// for unexpected content.
	if VersionCompare("v2.0.0.1-beta1", "v2.0.0.1-beta2") != Higher {
		t.Fatalf("Expecting value: Higher")
	}
}

func TestIsVersionTag(t *testing.T) {
	if isVersionTag("v0.4.4") == false {
		t.Fatal("Expecting true.")
	}
	if isVersionTag("v1") == false {
		t.Fatal("Expecting true.")
	}
	if isVersionTag("v2.1.1-beta") == false {
		t.Fatal("Expecting true.")
	}
	if isVersionTag("latest") == true {
		t.Fatal("Expecting false.")
	}
	if isVersionTag("new") == true {
		t.Fatal("Expecting false.")
	}
	if isVersionTag("vasdf") == true {
		t.Fatal("Expecting false.")
	}
}

func TestIsUpdateAsset(t *testing.T) {
	if isUpdateAsset("autoupdate-binary-windows-x86") == false {
		t.Fatal("Expecting true.")
	}
	if isUpdateAsset("autoupdate-binary-darwin-x86.dmg") == false {
		t.Fatal("Expecting true.")
	}
	if isUpdateAsset("autoupdate-binary-linux-x86.v1") == false {
		t.Fatal("Expecting true.")
	}
	if isUpdateAsset("Lantern.app") == true {
		t.Fatal("Expecting false.")
	}
	if isUpdateAsset("Lantern_Installer.app") == true {
		t.Fatal("Expecting false.")
	}
	if isUpdateAsset("autoupdate-binary") == true {
		t.Fatal("Expecting false.")
	}
}
