/* Package update allows a program to "self-update", replacing its executable file
with new bytes.

Package update provides the facility to create user experiences like auto-updating
or user-approved updates which manifest as user prompts in commercial applications
with copy similar to "Restart to begin using the new version of X".

Updating your program to a new version is as easy as:

	err, errRecover := update.New().FromUrl("http://release.example.com/2.0/myprogram")
	if err != nil {
		fmt.Printf("Update failed: %v", err)
	}

The most low-level API is (*Update) FromStream() which updates the current executable
with the bytes read from an io.Reader.

The most common, high-level API you'll probably want to use is (*Update) FromUrl()
which updates the current executable from a URL over the internet.

You may also update from a binary diff patch to preserve bandwidth like so:

    update.New().ApplyPatch().FromUrl("http://release.example.com/2.0/mypatch")

Package update also allows you to update arbitrary files on the file system (i.e. files
which are not the executable of the currently running program).

    update.New().Target("/usr/local/bin/some-program").FromUrl("http://release.example.com/2.0/some-program")

If requested, package update can additionally perform checksum verification and signing
verification to ensure the new binary is trusted.

Sub-package download contains functionality for downloading from an HTTP endpoint
while outputting a progress meter and supports resuming partial downloads.

Sub-package check contains the client functionality for a simple protocol for negotiating
whether a new update is available, where it is, and the metadata needed for verifying it.
*/
package update

import (
	"bitbucket.org/kardianos/osext"
	"bytes"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"github.com/inconshreveable/go-update/download"
	"github.com/kr/binarydist"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
)

type PatchType string

const (
	PATCHTYPE_BSDIFF = "bsdiff"
	PATCHTYPE_NONE   = ""
)

type Update struct {
	// empty string means "path of the current executable"
	TargetPath string

	// type of patch to apply. empty means "not a patch"
	PatchType

	// sha256 checksum of the new binary to verify against
	Checksum []byte

	// public key to use for signature verification
	PublicKey *rsa.PublicKey

	// signature to use for signature verification
	Signature []byte
}

func (u *Update) getPath() (string, error) {
	if u.TargetPath == "" {
		return osext.Executable()
	} else {
		return u.TargetPath, nil
	}
}

func New() *Update {
	return &Update{
		TargetPath: "",
		PatchType:  PATCHTYPE_NONE,
	}
}

func (u *Update) Target(path string) *Update {
	u.TargetPath = path
	return u
}

func (u *Update) VerifySignatureWith(publicKey *rsa.PublicKey) *Update {
	u.PublicKey = publicKey
	return u
}

func (u *Update) ApplyPatch(patchType PatchType) *Update {
	u.PatchType = patchType
	return u
}

func (u *Update) VerifyChecksum(checksum []byte) *Update {
	u.Checksum = checksum
	return u
}

func (u *Update) VerifySignature(signature []byte) *Update {
	u.Signature = signature
	return u
}

func (u *Update) VerifySignatureWithPEM(publicKeyPEM []byte) (*Update, error) {
	block, _ := pem.Decode(publicKeyPEM)
	if block == nil {
		return u, fmt.Errorf("Couldn't parse PEM data")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return u, err
	}

	var ok bool
	u.PublicKey, ok = pub.(*rsa.PublicKey)
	if !ok {
		return u, fmt.Errorf("Public key isn't an RSA public key")
	}

	return u, nil
}

// FromUrl downloads the contents of the given url and uses them to update
// the file at updatePath.
func (u *Update) FromUrl(url string) (err error, errRecover error) {
	target := new(download.MemoryTarget)
	err = download.New(url, target).Get()
	if err != nil {
		return
	}

	return u.FromStream(target)
}

// FromFile reads the contents of the given file and uses them
// to update the file by calling FromStream()
func (u *Update) FromFile(path string) (err error, errRecover error) {
	// open the new updated contents
	fp, err := os.Open(path)
	if err != nil {
		return
	}
	defer fp.Close()

	// do the update
	return u.FromStream(fp)
}

// FromStream reads the contents of the supplied io.Reader updateWith
// and uses them to update the file at updatePath.
//
// FromStream performs the following actions to ensure a cross-platform safe
// update:
//
// - Creates a new file, /path/to/.file-name.new with mode 0755 and copies
// the contents of updateWith into the file
//
// - Renames the file at updatePath from /path/to/file-name
// to /path/to/.file-name.old
//
// - Renames /path/to/.file-name.new to /path/to/file-name
//
// - If the rename is successful, it erases /path/to/.file-name.old. If this operation
// fails, no error is reported.
//
// - If the rename is unsuccessful, it attempts to rename /path/to/.file-name.old
// back to /path/to/file-name. If this operation fails, it is reported in the errRecover
// return value so as not to maks the error that caused the recovery attempt.
func (u *Update) FromStream(updateWith io.Reader) (err error, errRecover error) {
	updatePath, err := u.getPath()
	if err != nil {
		return
	}

	var newBytes []byte
	// apply a patch if requested
	switch u.PatchType {
	case PATCHTYPE_BSDIFF:
		newBytes, err = applyPatch(updateWith, updatePath)
		if err != nil {
			return
		}
	case PATCHTYPE_NONE:
		// no patch to apply, go on through
		newBytes, err = ioutil.ReadAll(updateWith)
		if err != nil {
			return
		}
	default:
		err = fmt.Errorf("Unrecognized patch type: %s", u.PatchType)
		return
	}

	// verify checksum if requested
	if u.Checksum != nil {
		if err = verifyChecksum(newBytes, u.Checksum); err != nil {
			return
		}
	}

	// verify signature if requested
	if u.Signature != nil {
		if err = verifySignature(newBytes, u.Signature, u.PublicKey); err != nil {
			return
		}
	}

	// get the directory the executable exists in
	updateDir := filepath.Dir(updatePath)
	filename := filepath.Base(updatePath)

	// Copy the contents of of newbinary to a the new executable file
	newPath := filepath.Join(updateDir, fmt.Sprintf(".%s.new", filename))
	fp, err := os.OpenFile(newPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
	if err != nil {
		return
	}
	defer fp.Close()
	_, err = io.Copy(fp, bytes.NewReader(newBytes))

	// if we don't call fp.Close(), windows won't let us move the new executable
	// because the file will still be "in use"
	fp.Close()

	// this is where we'll move the executable to so that we can swap in the updated replacement
	oldPath := filepath.Join(updateDir, fmt.Sprintf(".%s.old", filename))

	// delete any existing old exec file - this is necessary on Windows for two reasons:
	// 1. after a successful update, Windows can't remove the .old file because the process is still running
	// 2. windows rename operations fail if the destination file already exists
	_ = os.Remove(oldPath)

	// move the existing executable to a new file in the same directory
	err = os.Rename(updatePath, oldPath)
	if err != nil {
		return
	}

	// move the new exectuable in to become the new program
	err = os.Rename(newPath, updatePath)

	if err != nil {
		// copy unsuccessful
		errRecover = os.Rename(oldPath, updatePath)
	} else {
		// copy successful, remove the old binary
        errRemove := os.Remove(oldPath)

        // windows has trouble with removing old binaries, so hide it instead
        if errRemove != nil {
            _ = hideFile(oldPath)
        }
	}

	return
}

// CanUpdate() determines whether the process has the correct permissions to
// perform the requested update. If the update can proceed, it returns nil, otherwise
// it returns the error that would occur if an update were attempted.
func (u *Update) CanUpdate() (err error) {
	// get the directory the file exists in
	path, err := u.getPath()
	if err != nil {
		return
	}

	fileDir := filepath.Dir(path)
	fileName := filepath.Base(path)

	// attempt to open a file in the file's directory
	newPath := filepath.Join(fileDir, fmt.Sprintf(".%s.new", fileName))
	fp, err := os.OpenFile(newPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
	if err != nil {
		return
	}
	fp.Close()

	_ = os.Remove(newPath)
	return
}

func applyPatch(patch io.Reader, updatePath string) ([]byte, error) {
	// open the file to update
	old, err := os.Open(updatePath)
	if err != nil {
		return nil, err
	}
	defer old.Close()

	// apply the patch
	applied := new(bytes.Buffer)
	if err = binarydist.Patch(old, applied, patch); err != nil {
		return nil, err
	}

	return applied.Bytes(), nil
}

func verifyChecksum(updated []byte, expectedChecksum []byte) error {
	checksum, err := ChecksumForBytes(updated)
	if err != nil {
		return err
	}

	if !bytes.Equal(expectedChecksum, checksum) {
		return fmt.Errorf("Updated file has wrong checksum. Expected: %x, got: %x", expectedChecksum, checksum)
	}

	return nil
}

func ChecksumForFile(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	return ChecksumForReader(f)
}

func ChecksumForBytes(source []byte) ([]byte, error) {
	return ChecksumForReader(bytes.NewReader(source))
}

func ChecksumForReader(rd io.Reader) ([]byte, error) {
	h := sha256.New()
	if _, err := io.Copy(h, rd); err != nil {
		return nil, err
	}
	return h.Sum(nil), nil
}

func verifySignature(source, signature []byte, publicKey *rsa.PublicKey) error {
	checksum, err := ChecksumForBytes(source)
	if err != nil {
		return err
	}

	return rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, checksum, signature)
}
