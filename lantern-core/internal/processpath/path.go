// Package processpath normalizes executable paths used by split tunneling.
package processpath

// Normalize returns a platform-specific process-path identity.
//
// On Windows, paths are case-folded and drive-absolute paths are cleaned. Local
// drive-absolute 8.3 aliases are expanded when accessible without following
// reparse points. Other platforms return path unchanged.
func Normalize(path string) string {
	return normalize(path)
}
