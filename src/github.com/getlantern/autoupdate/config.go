package autoupdate

const (
	updateURI = `http://127.0.0.1:9197/update`
)

type config struct {
	publicKey []byte
}

var configMap = map[string]*config{
	"_test_app": &config{
		publicKey: []byte("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzSoibtACnqcp2uTGjCMJ\ntTOLDIMQ4oGPhGHT4Q/epum+H3hcbBNs9jRnMRWgX4z++xxuNJnhmoJw0eUXB7B4\nvj5DYpPajq6gPY8JuraF4ngfP5oxKj2BqpEUR9bx+3SjOSInrirM0JZO+aAW38BQ\nNJB+sS7JvbPjcwdjwKc5IKzc9kxxJNoZoFE9GMnYzaOrAlpCuAKWH8SCXYtCTxsX\nfKexdDxsI5Vzm5lQHJLMeqhLTQTUm9oQofwNAOGOkn6dD4ObMlmFTOsf1G03/Dl9\nsVgjaWaZ9bGjvJ9B85UxNeWwduy+uMrqFytxG6bbq0PbDEVu6ZQCPyiyCA7l945J\nOQIDAQAB\n-----END PUBLIC KEY-----\n"),
	},
}
