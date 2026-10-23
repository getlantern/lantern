//go:build !windows

package processpath

func normalize(path string) string {
	return path
}
