package app

import (
	"sync/atomic"

	"github.com/getlantern/bandwidth"
	"github.com/getlantern/i18n"
	"github.com/getlantern/notifier"
	proClient "github.com/getlantern/pro-server-client/go-client"

	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/flashlight/ui"
)

type notifyStatus struct {
	v uint32
}

var (
	no      notifyStatus = notifyStatus{0}
	ongoing notifyStatus = notifyStatus{1}
	yes     notifyStatus = notifyStatus{2}
	never   notifyStatus = notifyStatus{3}
)

func (s *notifyStatus) Set(newStatus notifyStatus) {
	atomic.StoreUint32(&s.v, newStatus.v)
}

// SetIf set s to 'newStatus' if the currrent status is 'expected'
func (s *notifyStatus) SetIf(expected, newStatus notifyStatus) bool {
	return atomic.CompareAndSwapUint32(&s.v, expected.v, newStatus.v)
}

var notified notifyStatus = no

func serveBandwidth(uiaddr string) error {
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending current bandwidth quota to new client")
		return write(bandwidth.GetQuota())
	}

	service, err := ui.Register("bandwidth", helloFn)
	if err == nil {
		go func() {
			n := notify.NewNotifications()
			for quota := range bandwidth.Updates {
				service.Out <- quota
				if quota.MiBAllowed <= quota.MiBUsed {
					if notified.SetIf(no, ongoing) {
						go notifyFreeUser(n, uiaddr)
					}
				}
			}
		}()
	}

	return err
}

func notifyFreeUser(n notify.Notifier, uiaddr string) {
	// revert to not notified when error happens, so the notifier can be shown next time
	defer notified.SetIf(ongoing, no)

	userId := settings.GetUserID()
	status, err := userStatus(int(userId), settings.GetToken())
	if err != nil {
		return
	}
	log.Debugf("User %d is %v", userId, status)
	if status != "active" {
		notified.Set(never)
		return
	}

	logo := "http://" + uiaddr + "/img/lantern_logo.png"
	msg := &notify.Notification{
		Title:    i18n.T("BACKEND_DATA_TITLE"),
		Message:  i18n.T("BACKEND_DATA_MESSAGE"),
		ClickURL: uiaddr,
		IconURL:  logo,
	}

	if err = n.Notify(msg); err != nil {
		log.Errorf("Could not notify? %v", err)
		return
	}
	notified.Set(yes)
}

func userStatus(id int, token string) (string, error) {
	user := proClient.User{Auth: proClient.Auth{
		ID:    id,
		Token: token,
	}}
	http, err := proxied.GetHTTPClient(true)
	if err != nil {
		log.Errorf("Unable to get proxied HTTP client: %v", err)
		return "", err
	}
	client := proClient.NewClient(http)
	resp, err := client.UserData(user)
	if err != nil {
		log.Errorf("Fail to get user data: %v", err)
		return "", err
	}

	return resp.User.UserStatus, nil
}
