package utils

type Opts struct {
	DataDir  string
	Deviceid string
	LogLevel string
	Locale   string
}

type PrivateServerEventListener interface {
	OpenBrowser(url string) error
	OnPrivateServerEvent(event string)
	OnError(err string)
}
