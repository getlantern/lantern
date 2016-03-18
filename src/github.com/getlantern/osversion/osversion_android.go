package osversion

import "fmt"

func GetString() (string, error) {
	return "0.0", nil
}

func GetHumanReadable() (string, error) {
	return fmt.Sprintf("%s %s", "Unknown", "0.0"), nil
}
