//go:build !stealth

package mobile

import lanterncore "github.com/getlantern/lantern/lantern-core"

// IsOAuthLogin returns true if the current user session was established via OAuth.
// Not available in stealth builds — regular email/password login only.
func IsOAuthLogin() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsOAuthLogin(), nil
	})
	if err != nil {
		return false
	}
	return ok
}

// GetOAuthProvider returns the OAuth provider used for the current session.
// Not available in stealth builds — regular email/password login only.
func GetOAuthProvider() string {
	provider, err := withCoreR(func(c lanterncore.Core) (string, error) {
		return c.GetOAuthProvider(), nil
	})
	if err != nil {
		return ""
	}
	return provider
}

// OAuth Methods

// OAuthLoginUrl returns the OAuth login URL for the given provider.
// Not available in stealth builds — regular email/password login only.
func OAuthLoginUrl(provider string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.OAuthLoginUrl(provider) })
}

// OAuthLoginCallback exchanges an OAuth token for a user session.
// Not available in stealth builds — regular email/password login only.
func OAuthLoginCallback(oAuthToken string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.OAuthLoginCallback(oAuthToken)
		return string(b), err
	})
}
