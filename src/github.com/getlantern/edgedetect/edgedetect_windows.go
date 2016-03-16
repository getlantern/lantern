package edgedetect

import (
	"strings"

	"golang.org/x/sys/windows/registry"
)

func defaultBrowserIsEdge() bool {
	k, err := registry.OpenKey(registry.CLASSES_ROOT, `ActivatableClasses\Package\DefaultBrowser_NOPUBLISHERID\Server\DefaultBrowserServer`, registry.QUERY_VALUE)
	if err != nil {
		log.Tracef("Error reading registry key: %v", err)
		return false
	}
	defer k.Close()

	s, _, err := k.GetStringValue("AppUserModelId")
	if err != nil {
		log.Tracef("Error reading AppUserModelId: %v", err)
		return false
	}

	log.Tracef("AppUserModelId: %v", s)
	return strings.Contains(s, "MicrosoftEdge")
}
