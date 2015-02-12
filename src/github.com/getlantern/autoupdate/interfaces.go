package autoupdate

// AutoUpdater defines methods to be satisfied by structs that can help other
// programs to update themselves.
type AutoUpdater interface {
	// SetVersion sets the internal release number of the source executable file.
	SetVersion(int)

	// Version returns the internal release number of the source executable file.
	Version() int

	// Query sends the current software checksum to an update server. If the
	// update server decides this program is outdated, it will send information
	// on how to update, this information can be used to build a Patcher.
	Query() (Patcher, error)

	// Watch will periodically check for updates (using Query()) without
	// interrupting the main process. If an update is found it will download and
	// apply it without user interaction.
	Watch()
}

// Patcher interface defines methods to be satisfied by structs that can patch
// the current process's executable file.
type Patcher interface {
	// Apply downloads and applies the binary diff against the actual program
	// file.  The returned value will be nil if, and only if, we're absolutely
	// sure the update was applied successfully.
	Apply() error

	// Version returns the internal release number of the update.
	Version() int
}
