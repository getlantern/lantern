package autoupdate

const (
	updateURI = `https://api.equinox.io/1/Updates`
)

type config struct {
	appID         string
	updateChannel string
	publicKey     []byte
}

var configMap = map[string]*config{
	"_test_app": &config{
		appID:         `ap_x4LawSVc-D1j6OKNckxeSfSe7z`,
		updateChannel: `stable`,
		publicKey:     []byte("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzSoibtACnqcp2uTGjCMJ\ntTOLDIMQ4oGPhGHT4Q/epum+H3hcbBNs9jRnMRWgX4z++xxuNJnhmoJw0eUXB7B4\nvj5DYpPajq6gPY8JuraF4ngfP5oxKj2BqpEUR9bx+3SjOSInrirM0JZO+aAW38BQ\nNJB+sS7JvbPjcwdjwKc5IKzc9kxxJNoZoFE9GMnYzaOrAlpCuAKWH8SCXYtCTxsX\nfKexdDxsI5Vzm5lQHJLMeqhLTQTUm9oQofwNAOGOkn6dD4ObMlmFTOsf1G03/Dl9\nsVgjaWaZ9bGjvJ9B85UxNeWwduy+uMrqFytxG6bbq0PbDEVu6ZQCPyiyCA7l945J\nOQIDAQAB\n-----END PUBLIC KEY-----\n"),
	},
}
