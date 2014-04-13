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
