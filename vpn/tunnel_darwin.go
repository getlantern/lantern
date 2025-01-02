//go:build !ios
// +build !ios

package vpn

type Tunnel interface {
	BaseTunnel
	Run() error
}

func (t *tunnel) Run() error {
	return t.Start()
}
