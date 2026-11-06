// Package processpath normalizes executable paths used by split tunneling.
package processpath

import (
	"regexp"
	"strings"
)

// The empty named group marks generated rules without changing their matches.
const aliasPatternPrefix = `(?i)^(?P<lantern_windows_executable>)`

// Normalize returns a platform-specific process-path identity.
//
// On Windows, paths are case-folded and drive-absolute paths are cleaned. Local
// drive-absolute 8.3 aliases are expanded when accessible without following
// reparse points. Other platforms return path unchanged.
func Normalize(path string) string {
	return normalize(path)
}

// AliasPattern matches an executable's verified Windows long and short names.
// It returns an empty string when no distinct, safely accessible alias exists.
func AliasPattern(path string) string {
	return aliasPattern(path)
}

// IsAliasPattern identifies rules managed alongside Lantern's executable list.
func IsAliasPattern(pattern string) bool {
	return strings.HasPrefix(pattern, aliasPatternPrefix)
}

func buildAliasPattern(parts, aliases []string) string {
	if len(parts) < 2 || len(parts) != len(aliases) {
		return ""
	}
	var pattern strings.Builder
	pattern.WriteString(aliasPatternPrefix)
	pattern.WriteString(regexp.QuoteMeta(parts[0]))
	distinct := false
	for i, part := range parts[1:] {
		pattern.WriteString(`\\`)
		alias := aliases[i+1]
		if alias == "" || strings.EqualFold(part, alias) {
			pattern.WriteString(regexp.QuoteMeta(part))
			continue
		}
		distinct = true
		pattern.WriteString(`(?:` + regexp.QuoteMeta(part) + `|` + regexp.QuoteMeta(alias) + `)`)
	}
	if !distinct {
		return ""
	}
	pattern.WriteByte('$')
	return pattern.String()
}
