package logging

import (
	"fmt"
	"sync"
)

type agentsMap map[string]int

var (
	userAgents  = make(agentsMap)
	agentsMutex = &sync.Mutex{}
)

// registerUserAgent tries to find the User-Agent in the HTTP request
// and keep track of the applications using Lantern during this session
func RegisterUserAgent(agent string) {
	// Do this asynchronously because it is not a critical operation,
	// so there is no wait for the mutex in the caller goroutine
	go func() {
		if agent != "" {
			agentsMutex.Lock()
			defer agentsMutex.Unlock()
			if n, ok := userAgents[agent]; ok {
				userAgents[agent] = n + 1
			} else {
				userAgents[agent] = 1
			}
		}
	}()
}

// getSessionUserAgents returns the
func GetSessionUserAgents() string {
	agentsMutex.Lock()
	defer agentsMutex.Unlock()
	return (fmt.Sprintf("%v", userAgents))
}
